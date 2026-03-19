#' Retrieve incremental entity updates
#'
#' Query the brreg change data capture (CDC) endpoint for entities
#' modified since a given date. Each update carries a monotonically
#' increasing `update_id` suitable for cursor-based pagination and
#' deduplication.
#'
#' @param since Date or POSIXct. Return updates after this timestamp.
#'   Defaults to yesterday.
#' @param size Integer. Number of updates per page (max 10000).
#' @param max_pages Integer. Maximum pages to fetch. Default 1.
#'   Set higher to paginate through large result sets automatically.
#' @param include_changes Logical. If `TRUE`, include field-level change
#'   details per update as a list-column of tibbles. The brreg API
#'   returns changes in a flat RFC 6902-style JSON Patch format.
#' @param type One of `"enheter"` (main entities), `"underenheter"`
#'   (sub-entities), or `"roller"` (role assignments). Roller updates
#'   use CloudEvents format (`afterTime`/`afterId` pagination) rather
#'   than the HAL-based format used by enheter/underenheter.
#'   `include_changes` is ignored for roller.
#' @param verbose Logical. Print page-level progress when
#'   `max_pages > 1`.
#'
#' @returns A tibble with columns: `update_id` (integer), `org_nr`
#'   (character), `change_type` (character: Ny/Endring/Sletting),
#'   `timestamp` (POSIXct). If `include_changes = TRUE`, an additional
#'   list-column `changes` contains tibbles with columns `operation`,
#'   `field`, `new_value`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_update_fields()] for a flat alternative,
#'   [brreg_entity()] to fetch the current state of a changed entity.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_updates(since = Sys.Date() - 1, size = 10)
#'
#' # With field-level change details
#' brreg_updates(since = Sys.Date() - 1, size = 5, include_changes = TRUE)
#'
#' # Auto-paginate through large result sets
#' brreg_updates(since = "2026-03-01", size = 10000, max_pages = 50,
#'               verbose = TRUE)
brreg_updates <- function(since = Sys.Date() - 1, size = 100,
                           max_pages = 1L,
                           include_changes = FALSE,
                           type = c("enheter", "underenheter", "roller"),
                           verbose = FALSE) {
  type <- match.arg(type)
  if (type == "roller") return(brreg_updates_roller(since, size))

  size <- min(as.integer(size), 10000L)
  all_pages <- vector("list", max_pages)
  cursor_id <- NULL

  for (page in seq_len(max_pages)) {
    query <- list(size = size)
    if (is.null(cursor_id)) {
      query$dato <- format(as.POSIXct(since), "%Y-%m-%dT00:00:00.000Z")
    } else {
      query$oppdateringsid <- cursor_id + 1L
    }
    if (include_changes) query$includeChanges <- "true"

    resp <- brreg_req(paste0("oppdateringer/", type)) |>
      httr2::req_url_query(!!!query) |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(resp) >= 400L) break

    body <- httr2::resp_body_json(resp)
    key <- paste0("oppdaterte", tools::toTitleCase(type))
    raw <- body[["_embedded"]][[key]]
    if (is.null(raw) || length(raw) == 0) break

    rows <- parse_updates_page(raw, include_changes = include_changes)
    all_pages[[page]] <- rows
    cursor_id <- max(rows$update_id)

    if (verbose) cli::cli_alert_info("Page {page}: {nrow(rows)} events (cursor {cursor_id})")
    if (nrow(rows) < size) break
  }

  all_pages <- all_pages[!vapply(all_pages, is.null, logical(1))]
  if (length(all_pages) == 0) return(tibble::tibble())
  dplyr::bind_rows(all_pages)
}


#' Retrieve field-level CDC changes as a flat tibble
#'
#' Convenience wrapper around [brreg_updates()] that returns one row
#' per field-level change instead of one row per event with a nested
#' `changes` list-column. Suitable for direct filtering, grouping,
#' and display in notebooks.
#'
#' @inheritParams brreg_updates
#'
#' @returns A tibble with columns: `update_id`, `org_nr`, `change_type`,
#'   `timestamp`, `operation`, `field`, `new_value`. No list-columns.
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
  cdc <- brreg_updates(
    since = since, size = size, max_pages = max_pages,
    include_changes = TRUE, type = type, verbose = verbose
  )

  empty <- tibble::tibble(
    update_id = integer(), org_nr = character(),
    change_type = character(), timestamp = as.POSIXct(character()),
    operation = character(), field = character(),
    new_value = character()
  )

  if (nrow(cdc) == 0 || !"changes" %in% names(cdc)) return(empty)

  has_changes <- vapply(cdc$changes, \(x) is.data.frame(x) && nrow(x) > 0, logical(1))
  if (!any(has_changes)) return(empty)

  idx <- which(has_changes)
  expanded <- dplyr::bind_rows(lapply(idx, \(i) {
    ch <- cdc$changes[[i]]
    ch$update_id <- cdc$update_id[i]
    ch$org_nr <- cdc$org_nr[i]
    ch$change_type <- cdc$change_type[i]
    ch$timestamp <- cdc$timestamp[i]
    ch
  }))

  expanded[, c("update_id", "org_nr", "change_type", "timestamp",
               "operation", "field", "new_value")]
}


#' Fetch roller updates (CloudEvents format)
#' @keywords internal
brreg_updates_roller <- function(since, size) {
  after_time <- format(as.POSIXct(since), "%Y-%m-%dT00:00:00.000Z")
  query <- list(afterTime = after_time, size = min(size, 10000L))

  resp <- brreg_req("oppdateringer/roller") |>
    httr2::req_url_query(!!!query) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) return(tibble::tibble())

  events <- httr2::resp_body_json(resp)
  if (length(events) == 0) return(tibble::tibble())

  n <- length(events)
  ids <- integer(n)
  orgs <- character(n)
  types <- character(n)
  timestamps <- character(n)

  for (i in seq_len(n)) {
    e <- events[[i]]
    ids[i] <- as.integer(e$id %||% NA)
    orgs[i] <- e$data$organisasjonsnummer %||% NA_character_
    types[i] <- sub(".*\\.", "", e$type %||% "")
    timestamps[i] <- e$time %||% NA_character_
  }

  tibble::tibble(
    update_id   = ids,
    org_nr      = orgs,
    change_type = types,
    timestamp   = as.POSIXct(timestamps, format = "%Y-%m-%dT%H:%M:%OS")
  )
}


#' Parse a page of raw CDC update objects into a tibble
#' @param raw_updates List of update objects from the API.
#' @param include_changes Logical. Parse and attach field changes.
#' @keywords internal
parse_updates_page <- function(raw_updates, include_changes = FALSE) {
  n <- length(raw_updates)
  if (n == 0L) {
    return(tibble::tibble(
      update_id = integer(), org_nr = character(),
      change_type = character(), timestamp = as.POSIXct(character())
    ))
  }

  ids <- integer(n)
  orgs <- character(n)
  types <- character(n)
  timestamps <- character(n)

  for (i in seq_len(n)) {
    u <- raw_updates[[i]]
    ids[i] <- u$oppdateringsid %||% NA_integer_
    orgs[i] <- u$organisasjonsnummer %||% NA_character_
    types[i] <- u$endringstype %||% NA_character_
    timestamps[i] <- u$dato %||% NA_character_
  }

  result <- tibble::tibble(
    update_id   = ids,
    org_nr      = orgs,
    change_type = types,
    timestamp   = as.POSIXct(timestamps, format = "%Y-%m-%dT%H:%M:%OS")
  )

  if (include_changes) {
    changes_list <- vector("list", n)
    for (i in seq_len(n)) {
      u <- raw_updates[[i]]
      if (!is.null(u$endringer) && length(u$endringer) > 0) {
        changes_list[[i]] <- parse_patch(u$endringer)
      } else {
        changes_list[[i]] <- tibble::tibble(
          operation = character(), field = character(), new_value = character()
        )
      }
    }
    result$changes <- changes_list
  }

  result
}


#' Parse brreg RFC 6902 JSON Patch operations into a tibble
#'
#' Uses a collector-based approach: accumulates into pre-allocated
#' character vectors and builds a single tibble at the end. Nested
#' objects are flattened to leaf-level rows so that `/naeringskode1`
#' with value `{kode: "43.210", beskrivelse: "..."}` produces two
#' rows: `naeringskode1_kode` and `naeringskode1_beskrivelse`.
#' NULL values in arrays produce `NA_character_`.
#'
#' @param endringer List of patch operations from the brreg API.
#'
#' @returns A tibble with columns `operation`, `field`, `new_value`.
#'
#' @keywords internal
parse_patch <- function(endringer) {
  empty <- tibble::tibble(
    operation = character(), field = character(), new_value = character()
  )
  if (is.null(endringer) || length(endringer) == 0) return(empty)

  ops <- character(length(endringer) * 10L)
  fields <- character(length(endringer) * 10L)
  values <- character(length(endringer) * 10L)
  k <- 0L

  for (e in endringer) {
    op <- e$op %||% NA_character_
    path <- sub("^/", "", e$path %||% "")

    if (op == "remove" || is.null(e$value)) {
      k <- k + 1L
      if (k > length(ops)) {
        ops <- c(ops, character(length(ops)))
        fields <- c(fields, character(length(fields)))
        values <- c(values, character(length(values)))
      }
      ops[k] <- op
      fields[k] <- gsub("/", "_", path)
      values[k] <- NA_character_
      next
    }

    flatten_value_into(op, path, e$value, function(o, f, v) {
      k <<- k + 1L
      if (k > length(ops)) {
        ops <<- c(ops, character(length(ops)))
        fields <<- c(fields, character(length(fields)))
        values <<- c(values, character(length(values)))
      }
      ops[k] <<- o
      fields[k] <<- f
      values[k] <<- v
    })
  }

  if (k == 0L) return(empty)

  tibble::tibble(
    operation = ops[seq_len(k)],
    field     = fields[seq_len(k)],
    new_value = values[seq_len(k)]
  )
}


#' Recursively flatten a patch value, calling emit() for each leaf
#' @param op Character. The patch operation.
#' @param path_prefix Character. Current path being traversed.
#' @param value The value to flatten.
#' @param emit Function(op, field, value) called at each leaf.
#' @keywords internal
flatten_value_into <- function(op, path_prefix, value, emit) {
  if (is.null(value) || (is.atomic(value) && length(value) == 0)) {
    emit(op, gsub("/", "_", path_prefix), NA_character_)
  } else if (is.list(value) && !is.null(names(value))) {
    for (key in names(value)) {
      flatten_value_into(op, paste0(path_prefix, "/", key), value[[key]], emit)
    }
  } else if (is.list(value) && is.null(names(value))) {
    for (i in seq_along(value)) {
      flatten_value_into(op, paste0(path_prefix, "/", i - 1L), value[[i]], emit)
    }
  } else {
    emit(op, gsub("/", "_", path_prefix), as.character(value))
  }
}
