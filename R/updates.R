#' Retrieve incremental entity updates
#'
#' Query the brreg change data capture (CDC) endpoint for entities
#' modified since a given instant. Each update carries a monotonically
#' increasing `update_id` suitable for cursor-based pagination and
#' deduplication.
#'
#' @section Time handling:
#' `since` is sent to the feed as a UTC instant. A `POSIXct` keeps its
#' full precision; a `Date` is midnight UTC of that day; an ISO 8601
#' string (`"2026-03-01"` or `"2026-03-01T14:00:00Z"`) is parsed as UTC.
#' Timestamps in the result are `POSIXct` in the `UTC` time zone,
#' whatever the session time zone.
#'
#' @section Completeness:
#' The feed is read page by page until a page is short, the feed is
#' exhausted, or `max_pages` is reached. The result carries attributes
#' `complete` (`FALSE` when `max_pages` stopped the read while the last
#' page was full, or a later page failed), `pages_fetched`, and `cursor`
#' (the last `update_id` read; pass `update_id + 1` as the next cursor
#' to resume). Stopping on `max_pages` signals a
#' `tidybrreg_warning_truncated`; a failure after the first page signals
#' a `tidybrreg_warning_partial` and returns the pages already read; a
#' failure on the first page aborts with a `tidybrreg_error_http`.
#'
#' @section Unknown members:
#' Any member of an update object that the package does not model is
#' passed through as a column named by its snake_case key, and the
#' result carries attribute `unknown_members` plus a single
#' `tidybrreg_warning_unknown_member`, so an upstream addition cannot
#' vanish silently.
#'
#' @param since Date, POSIXct, or ISO 8601 string. Return updates at or
#'   after this instant. Defaults to yesterday (midnight UTC).
#' @param size Integer. Number of updates per page (max 10000).
#' @param max_pages Integer. Maximum pages to fetch. Default 1.
#'   Set higher to paginate through large result sets automatically.
#' @param include_changes Logical. If `TRUE`, include field-level change
#'   details per update as a list-column of tibbles. Not available for
#'   `type = "roller"`, whose feed carries no field patches; supplying
#'   `TRUE` there is an error.
#' @param type One of `"enheter"`, `"underenheter"`, or `"roller"`.
#'   The roller feed uses the CloudEvents format and reports only which
#'   entity's roles changed; fetch the new state with [brreg_roles()].
#' @param verbose Logical. Print page-level progress.
#'
#' @returns A tibble with columns: `update_id` (integer), `org_nr`,
#'   `change_type`, `timestamp` (POSIXct, UTC). If `include_changes =
#'   TRUE`, a list-column `changes` with tibbles of `operation`, `field`,
#'   `path`, `new_value`. An empty feed yields a zero-row tibble with the
#'   same typed columns.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_update_fields()] for a flat alternative,
#'   [tidybrreg_conditions] for the conditions signalled.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_updates(since = Sys.Date() - 1, size = 10)
#'
#' # Auto-paginate
#' brreg_updates(since = "2026-03-01", size = 10000, max_pages = 50,
#'               verbose = TRUE)
brreg_updates <- function(since = Sys.Date() - 1, size = 100,
                           max_pages = 1L,
                           include_changes = FALSE,
                           type = c("enheter", "underenheter", "roller"),
                           verbose = FALSE) {
  type <- match.arg(type)
  size <- min(as.integer(size), 10000L)
  max_pages <- as.integer(max_pages)
  if (type == "roller") {
    if (isTRUE(include_changes)) {
      brreg_abort(c(
        "{.arg include_changes} is not available for {.val roller}.",
        "i" = "The roller feed carries no field patches; fetch the new state with {.fn brreg_roles}."
      ), class = "invalid_filter", registry = "roller", filter = "include_changes")
    }
    return(brreg_updates_roller(since, size, max_pages, verbose))
  }

  feed <- fetch_update_pages(type, since, size, max_pages,
                             include_changes = include_changes,
                             verbose = verbose)
  pages <- lapply(feed$pages, parse_updates_page, include_changes = include_changes)
  result <- if (length(pages) == 0) empty_updates(include_changes) else dplyr::bind_rows(pages)
  unknown <- unique(unlist(lapply(pages, attr, "unknown_members")))
  finish_updates(result, feed, unknown)
}

#' Typed zero-row tibble for update feeds
#' @keywords internal
empty_updates <- function(include_changes = FALSE) {
  out <- tibble::tibble(
    update_id = integer(), org_nr = character(),
    change_type = character(),
    timestamp = as.POSIXct(character(), tz = "UTC")
  )
  if (include_changes) out$changes <- list()
  out
}

#' Attach completeness metadata to a feed result
#' @keywords internal
finish_updates <- function(result, feed, unknown = character()) {
  attr(result, "complete") <- feed$complete
  attr(result, "pages_fetched") <- feed$pages_fetched
  attr(result, "cursor") <- feed$cursor
  if (length(unknown) > 0) {
    attr(result, "unknown_members") <- unknown
    brreg_warn(c(
      "The {feed$type} feed carried member{?s} not modelled by tidybrreg: {.val {unknown}}.",
      "i" = "They are passed through as columns; see {.code attr(x, \"unknown_members\")}."
    ), class = "unknown_member", members = unknown)
  }
  result
}

#' Read pages from an enheter/underenheter update feed
#'
#' Shared paginator for [brreg_updates()] and [brreg_update_fields()].
#' The first page is addressed by `dato`, later pages by the exclusive
#' cursor `oppdateringsid = max(update_id) + 1`.
#' @returns A list with `pages` (raw update objects per page), `complete`,
#'   `pages_fetched`, `cursor`, `type`.
#' @keywords internal
fetch_update_pages <- function(type, since, size, max_pages,
                               include_changes = FALSE, verbose = FALSE) {
  key <- paste0("oppdaterte", tools::toTitleCase(type))
  endpoint <- paste0("oppdateringer/", type)
  pages <- list()
  cursor_id <- NULL
  complete <- TRUE
  last_full <- FALSE

  for (page in seq_len(max_pages)) {
    query <- list(size = size)
    if (is.null(cursor_id)) {
      query$dato <- format_since(since)
    } else {
      query$oppdateringsid <- cursor_id + 1L
    }
    if (include_changes) query$includeChanges <- "true"

    resp <- brreg_perform(brreg_req(endpoint, query = query))
    status <- httr2::resp_status(resp)
    if (status >= 400L) {
      if (length(pages) == 0) abort_http(resp, endpoint)
      brreg_warn(c(
        "The {type} feed failed with HTTP {status} after {length(pages)} page{?s}; returning the events read so far.",
        "i" = "The result carries {.code attr(x, \"complete\") == FALSE}."
      ), class = "partial", endpoint = endpoint, status = status,
      pages_fetched = length(pages))
      complete <- FALSE
      last_full <- FALSE
      break
    }

    body <- httr2::resp_body_json(resp)
    raw <- body[["_embedded"]][[key]]
    if (is.null(raw) || length(raw) == 0) { last_full <- FALSE; break }

    pages[[length(pages) + 1L]] <- raw
    ids <- vapply(raw, function(u) as.integer(u$oppdateringsid %||% NA_integer_), integer(1))
    cursor_id <- max(ids, na.rm = TRUE)
    if (verbose) cli::cli_alert_info("Page {page}: {length(raw)} events (cursor {cursor_id})")
    last_full <- length(raw) >= size
    if (!last_full) break
  }

  if (last_full && length(pages) == max_pages) {
    complete <- FALSE
    brreg_warn(c(
      "Stopped after {max_pages} page{?s} with a full last page; more events may follow.",
      "i" = "Raise {.arg max_pages} or resume from {.code attr(x, \"cursor\") + 1}."
    ), class = "truncated", endpoint = endpoint, returned = length(pages) * size,
    total_matches = NA_integer_)
  }
  list(pages = pages, complete = complete, pages_fetched = length(pages),
       cursor = cursor_id, type = type)
}


#' Retrieve field-level CDC changes as a flat tibble
#'
#' Returns one row per field-level change, plus one synthetic row for
#' each event that carries no field patches (Ny, Sletting, Fjernet).
#' Synthetic rows have `operation = NA`, `field = NA`, `path = NA`,
#' `new_value = NA`, preserving event-level metadata in the output.
#'
#' Patches are RFC 6902 operations. Nested values are flattened to one
#' row per leaf; `path` keeps the raw JSON pointer of the leaf (for
#' example `/forretningsadresse/adresse/0`) and `field` its snake_case
#' rendering, so the register's own representation is never lost. A
#' `move` emits an add at the destination and a `remove` at the source.
#'
#' To retrieve initial field values for newly registered entities
#' (change_type `"Ny"`), call [brreg_entity()] per org_nr — the CDC
#' payload for Ny events contains no field-level patches.
#'
#' @inheritSection brreg_updates Time handling
#' @inheritSection brreg_updates Completeness
#' @inheritSection brreg_updates Unknown members
#'
#' @inheritParams brreg_updates
#' @param type One of `"enheter"` or `"underenheter"`.
#'
#' @returns A tibble with columns: `update_id`, `org_nr`, `change_type`,
#'   `timestamp` (POSIXct, UTC), `operation`, `field`, `path`,
#'   `new_value`. No list-columns. Events without field patches appear
#'   as rows with `operation`, `field`, `path` and `new_value` all `NA`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_updates()] for the event-level view.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_update_fields(since = Sys.Date() - 1, size = 50)
brreg_update_fields <- function(since = Sys.Date() - 1, size = 100,
                                 max_pages = 1L,
                                 type = c("enheter", "underenheter"),
                                 verbose = FALSE) {
  type <- match.arg(type)
  size <- min(as.integer(size), 10000L)
  max_pages <- as.integer(max_pages)

  feed <- fetch_update_pages(type, since, size, max_pages,
                             include_changes = TRUE, verbose = verbose)
  pages <- lapply(feed$pages, flatten_page_patches)
  result <- if (length(pages) == 0) empty_update_fields() else dplyr::bind_rows(pages)
  unknown <- unique(unlist(lapply(pages, attr, "unknown_members")))
  finish_updates(result, feed, unknown)
}

#' Typed zero-row tibble for flat field changes
#' @keywords internal
empty_update_fields <- function() {
  tibble::tibble(
    update_id = integer(), org_nr = character(),
    change_type = character(),
    timestamp = as.POSIXct(character(), tz = "UTC"),
    operation = character(), field = character(), path = character(),
    new_value = character()
  )
}

#' Members of an update object the package models explicitly
#' @keywords internal
known_update_members <- function() {
  c("oppdateringsid", "organisasjonsnummer", "endringstype", "dato",
    "endringer", "_links")
}

#' Flatten all patches from a page of CDC events
#'
#' One row per patch leaf via [parse_patch()], so nesting of any depth
#' is handled identically to the `changes` list-column of
#' [brreg_updates()]. Events with no `endringer` emit one synthetic row.
#'
#' @param raw_updates List of raw update objects from the API.
#' @returns A flat tibble; see [brreg_update_fields()].
#' @keywords internal
flatten_page_patches <- function(raw_updates) {
  if (length(raw_updates) == 0) return(empty_update_fields())
  head <- parse_updates_page(raw_updates, include_changes = TRUE)
  per_event <- lapply(seq_len(nrow(head)), function(i) {
    ch <- head$changes[[i]]
    meta <- head[i, setdiff(names(head), "changes")]
    if (nrow(ch) == 0) {
      ch <- tibble::tibble(operation = NA_character_, field = NA_character_,
                           path = NA_character_, new_value = NA_character_)
    }
    dplyr::bind_cols(meta[rep(1L, nrow(ch)), ], ch)
  })
  out <- dplyr::bind_rows(per_event)
  attr(out, "unknown_members") <- attr(head, "unknown_members")
  out
}


#' Fetch roller updates (CloudEvents format)
#'
#' The roller feed is addressed by `afterTime` for the first page and by
#' `afterId` (the last event id read) for later pages.
#' @keywords internal
brreg_updates_roller <- function(since, size, max_pages = 1L, verbose = FALSE) {
  endpoint <- "oppdateringer/roller"
  pages <- list()
  cursor_id <- NULL
  complete <- TRUE
  last_full <- FALSE

  for (page in seq_len(max_pages)) {
    query <- list(size = size)
    if (is.null(cursor_id)) {
      query$afterTime <- format_since(since)
    } else {
      query$afterId <- cursor_id
    }
    resp <- brreg_perform(brreg_req(endpoint, query = query))
    status <- httr2::resp_status(resp)
    if (status >= 400L) {
      if (length(pages) == 0) abort_http(resp, endpoint)
      brreg_warn(c(
        "The roller feed failed with HTTP {status} after {length(pages)} page{?s}; returning the events read so far.",
        "i" = "The result carries {.code attr(x, \"complete\") == FALSE}."
      ), class = "partial", endpoint = endpoint, status = status,
      pages_fetched = length(pages))
      complete <- FALSE
      last_full <- FALSE
      break
    }
    events <- httr2::resp_body_json(resp)
    if (length(events) == 0) { last_full <- FALSE; break }
    pages[[length(pages) + 1L]] <- parse_roller_page(events)
    cursor_id <- max(pages[[length(pages)]]$update_id, na.rm = TRUE)
    if (verbose) cli::cli_alert_info("Page {page}: {length(events)} events (cursor {cursor_id})")
    last_full <- length(events) >= size
    if (!last_full) break
  }
  if (last_full && length(pages) == max_pages) {
    complete <- FALSE
    brreg_warn(c(
      "Stopped after {max_pages} page{?s} with a full last page; more events may follow.",
      "i" = "Raise {.arg max_pages} or resume from {.code attr(x, \"cursor\")}."
    ), class = "truncated", endpoint = endpoint, returned = length(pages) * size,
    total_matches = NA_integer_)
  }
  result <- if (length(pages) == 0) empty_updates() else dplyr::bind_rows(pages)
  unknown <- unique(unlist(lapply(pages, attr, "unknown_members")))
  finish_updates(result, list(complete = complete, pages_fetched = length(pages),
                              cursor = cursor_id, type = "roller"), unknown)
}

#' Text of an update member the package does not model
#'
#' Scalars as character, arrays joined by newline, objects as JSON
#' text: the member's shape is unknown, so nothing is asserted about it
#' beyond its text.
#' @keywords internal
member_text <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.list(x) && !is.null(names(x))) return(as.character(jsonlite::toJSON(x, auto_unbox = TRUE)))
  if (is.list(x) && any(vapply(x, is.list, logical(1)))) return(as.character(jsonlite::toJSON(x, auto_unbox = TRUE)))
  paste(as.character(unlist(x)), collapse = "\n")
}

#' Parse one page of roller CloudEvents
#' @keywords internal
parse_roller_page <- function(events) {
  n <- length(events)
  ids <- integer(n); orgs <- character(n); types <- character(n); ts <- character(n)
  known <- c("specversion", "id", "source", "type", "time", "data",
             "datacontenttype", "subject")
  extra <- list()
  for (i in seq_len(n)) {
    e <- events[[i]]
    ids[i] <- as.integer(e$id %||% NA)
    orgs[i] <- e$data$organisasjonsnummer %||% NA_character_
    types[i] <- sub(".*\\.", "", e$type %||% "")
    ts[i] <- e$time %||% NA_character_
    for (nm in setdiff(names(e), known)) {
      if (is.null(extra[[nm]])) extra[[nm]] <- rep(NA_character_, n)
      extra[[nm]][i] <- member_text(e[[nm]])
    }
  }
  out <- tibble::tibble(update_id = ids, org_nr = orgs, change_type = types,
                        timestamp = parse_brreg_instant(ts))
  for (nm in names(extra)) out[[to_snake(nm)]] <- extra[[nm]]
  attr(out, "unknown_members") <- names(extra)
  out
}


#' Parse a page of raw CDC update objects into a tibble
#' @param raw_updates List of update objects from the API.
#' @param include_changes Logical. Parse and attach field changes.
#' @keywords internal
parse_updates_page <- function(raw_updates, include_changes = FALSE) {
  n <- length(raw_updates)
  if (n == 0L) return(empty_updates(include_changes))

  ids <- integer(n); orgs <- character(n); types <- character(n); ts <- character(n)
  extra <- list()
  for (i in seq_len(n)) {
    u <- raw_updates[[i]]
    ids[i] <- as.integer(u$oppdateringsid %||% NA_integer_)
    orgs[i] <- u$organisasjonsnummer %||% NA_character_
    types[i] <- u$endringstype %||% NA_character_
    ts[i] <- u$dato %||% NA_character_
    for (nm in setdiff(names(u), known_update_members())) {
      if (is.null(extra[[nm]])) extra[[nm]] <- rep(NA_character_, n)
      extra[[nm]][i] <- member_text(u[[nm]])
    }
  }

  result <- tibble::tibble(
    update_id   = ids,
    org_nr      = orgs,
    change_type = types,
    timestamp   = parse_brreg_instant(ts)
  )
  for (nm in names(extra)) result[[to_snake(nm)]] <- extra[[nm]]

  if (include_changes) {
    result$changes <- lapply(raw_updates, function(u) parse_patch(u$endringer))
  }
  attr(result, "unknown_members") <- names(extra)
  result
}


#' Parse brreg RFC 6902 JSON Patch operations into a tibble
#'
#' Collector-based with pre-allocated vectors. Used by
#' [parse_updates_page()] and [flatten_page_patches()].
#'
#' RFC 6902 `move` operations emit two rows: an add/replace at the
#' destination path and a `remove` at the source path (from `$from`).
#' `copy` operations emit one row at the destination.
#'
#' @param endringer List of patch operations from the brreg API.
#' @returns A tibble with columns `operation`, `field`, `path`, `new_value`.
#' @keywords internal
parse_patch <- function(endringer) {
  empty <- tibble::tibble(
    operation = character(), field = character(), path = character(),
    new_value = character()
  )
  if (is.null(endringer) || length(endringer) == 0) return(empty)

  cap <- length(endringer) * 10L
  ops <- character(cap); fields <- character(cap); paths <- character(cap)
  values <- character(cap)
  k <- 0L
  push <- function(o, p, v) {
    k <<- k + 1L
    if (k > length(ops)) {
      ops <<- c(ops, character(length(ops)))
      fields <<- c(fields, character(length(fields)))
      paths <<- c(paths, character(length(paths)))
      values <<- c(values, character(length(values)))
    }
    ops[k] <<- o
    paths[k] <<- p
    fields[k] <<- gsub("/", "_", sub("^/", "", p))
    values[k] <<- v
  }

  for (e in endringer) {
    op <- e$op %||% NA_character_
    path <- e$path %||% ""
    if (identical(op, "remove") || is.null(e$value)) {
      push(op, path, NA_character_)
      next
    }
    flatten_value_into(op, path, e$value, push)
    if (identical(op, "move") && !is.null(e$from)) {
      push("remove", e$from, NA_character_)
    }
  }

  if (k == 0L) return(empty)
  tibble::tibble(
    operation = ops[seq_len(k)],
    field     = fields[seq_len(k)],
    path      = paths[seq_len(k)],
    new_value = values[seq_len(k)]
  )
}


#' Recursively flatten a patch value, calling emit() for each leaf
#' @param emit Function of `(op, path, value)` where `path` is the raw
#'   JSON pointer of the leaf.
#' @keywords internal
flatten_value_into <- function(op, path_prefix, value, emit) {
  if (is.null(value) || (is.atomic(value) && length(value) == 0)) {
    emit(op, path_prefix, NA_character_)
  } else if (is.list(value) && !is.null(names(value))) {
    for (key in names(value)) {
      flatten_value_into(op, paste0(path_prefix, "/", key), value[[key]], emit)
    }
  } else if (is.list(value) && is.null(names(value))) {
    for (i in seq_along(value)) {
      flatten_value_into(op, paste0(path_prefix, "/", i - 1L), value[[i]], emit)
    }
  } else if (length(value) > 1L) {
    for (i in seq_along(value)) {
      emit(op, paste0(path_prefix, "/", i - 1L), as.character(value[[i]]))
    }
  } else {
    emit(op, path_prefix, as.character(value))
  }
}
