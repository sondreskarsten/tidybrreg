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
#'   details per update as a list-column of tibbles.
#' @param type One of `"enheter"`, `"underenheter"`, or `"roller"`.
#'   Roller uses CloudEvents format; `include_changes` is ignored.
#' @param verbose Logical. Print page-level progress.
#'
#' @returns A tibble with columns: `update_id`, `org_nr`,
#'   `change_type`, `timestamp`. If `include_changes = TRUE`, a
#'   list-column `changes` with tibbles of `operation`, `field`,
#'   `new_value`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_update_fields()] for a flat alternative.
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
#' Returns one row per field-level change. All events from all pages
#' are flattened in a single pass with no recursion — substantially
#' faster than [brreg_updates()] with `include_changes = TRUE`
#' followed by unnesting.
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
  size <- min(as.integer(size), 10000L)

  empty <- tibble::tibble(
    update_id = integer(), org_nr = character(),
    change_type = character(), timestamp = as.POSIXct(character()),
    operation = character(), field = character(),
    new_value = character()
  )

  cursor_id <- NULL
  all_results <- vector("list", max_pages)

  for (page in seq_len(max_pages)) {
    query <- list(size = size, includeChanges = "true")
    if (is.null(cursor_id)) {
      query$dato <- format(as.POSIXct(since), "%Y-%m-%dT00:00:00.000Z")
    } else {
      query$oppdateringsid <- cursor_id + 1L
    }

    resp <- brreg_req(paste0("oppdateringer/", type)) |>
      httr2::req_url_query(!!!query) |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(resp) >= 400L) break

    body <- httr2::resp_body_json(resp)
    key <- paste0("oppdaterte", tools::toTitleCase(type))
    raw <- body[["_embedded"]][[key]]
    if (is.null(raw) || length(raw) == 0) break

    flat <- flatten_page_patches(raw)
    all_results[[page]] <- flat
    cursor_id <- max(flat$update_id, na.rm = TRUE)

    if (verbose) {
      n_events <- length(raw)
      cli::cli_alert_info("Page {page}: {n_events} events, {nrow(flat)} fields (cursor {cursor_id})")
    }
    if (length(raw) < size) break
  }

  all_results <- all_results[!vapply(all_results, is.null, logical(1))]
  if (length(all_results) == 0) return(empty)
  dplyr::bind_rows(all_results)
}


#' Flatten all patches from a page of CDC events in a single pass
#'
#' No recursion. The brreg CDC nesting depth is bounded at 2 levels:
#' object -> scalar, or object -> array -> scalar. This function
#' inlines the unpack for both levels, avoiding function call overhead,
#' closure allocation, and `<<-` assignment entirely.
#'
#' @param raw_updates List of raw update objects from the API.
#' @returns A flat tibble with update_id, org_nr, change_type,
#'   timestamp, operation, field, new_value.
#' @keywords internal
flatten_page_patches <- function(raw_updates) {
  n_est <- length(raw_updates) * 8L
  r_uid   <- integer(n_est)
  r_org   <- character(n_est)
  r_ctype <- character(n_est)
  r_ts    <- character(n_est)
  r_op    <- character(n_est)
  r_field <- character(n_est)
  r_val   <- character(n_est)
  k <- 0L

  for (u in raw_updates) {
    uid   <- u$oppdateringsid %||% NA_integer_
    org   <- u$organisasjonsnummer %||% NA_character_
    ctype <- u$endringstype %||% NA_character_
    ts    <- u$dato %||% NA_character_

    endringer <- u$endringer
    if (is.null(endringer) || length(endringer) == 0) next

    for (e in endringer) {
      op <- e$op %||% NA_character_
      path <- sub("^/", "", e$path %||% "")
      val <- e$value

      if (op == "remove" || is.null(val)) {
        k <- k + 1L
        if (k > length(r_uid)) {
          r_uid   <- c(r_uid, integer(length(r_uid)))
          r_org   <- c(r_org, character(length(r_org)))
          r_ctype <- c(r_ctype, character(length(r_ctype)))
          r_ts    <- c(r_ts, character(length(r_ts)))
          r_op    <- c(r_op, character(length(r_op)))
          r_field <- c(r_field, character(length(r_field)))
          r_val   <- c(r_val, character(length(r_val)))
        }
        r_uid[k]   <- uid
        r_org[k]   <- org
        r_ctype[k] <- ctype
        r_ts[k]    <- ts
        r_op[k]    <- op
        r_field[k] <- gsub("/", "_", path)
        r_val[k]   <- NA_character_
        next
      }

      if (is.atomic(val) && length(val) == 1L) {
        k <- k + 1L
        if (k > length(r_uid)) {
          r_uid   <- c(r_uid, integer(length(r_uid)))
          r_org   <- c(r_org, character(length(r_org)))
          r_ctype <- c(r_ctype, character(length(r_ctype)))
          r_ts    <- c(r_ts, character(length(r_ts)))
          r_op    <- c(r_op, character(length(r_op)))
          r_field <- c(r_field, character(length(r_field)))
          r_val   <- c(r_val, character(length(r_val)))
        }
        r_uid[k]   <- uid
        r_org[k]   <- org
        r_ctype[k] <- ctype
        r_ts[k]    <- ts
        r_op[k]    <- op
        r_field[k] <- gsub("/", "_", path)
        r_val[k]   <- as.character(val)
        next
      }

      if (is.list(val) && !is.null(names(val))) {
        for (key in names(val)) {
          child <- val[[key]]
          child_path <- paste0(path, "_", key)

          if (is.null(child) || (is.atomic(child) && length(child) == 0L)) {
            k <- k + 1L
            if (k > length(r_uid)) {
              r_uid   <- c(r_uid, integer(length(r_uid)))
              r_org   <- c(r_org, character(length(r_org)))
              r_ctype <- c(r_ctype, character(length(r_ctype)))
              r_ts    <- c(r_ts, character(length(r_ts)))
              r_op    <- c(r_op, character(length(r_op)))
              r_field <- c(r_field, character(length(r_field)))
              r_val   <- c(r_val, character(length(r_val)))
            }
            r_uid[k] <- uid; r_org[k] <- org; r_ctype[k] <- ctype; r_ts[k] <- ts
            r_op[k] <- op; r_field[k] <- gsub("/", "_", child_path); r_val[k] <- NA_character_
          } else if (is.list(child) && is.null(names(child))) {
            for (j in seq_along(child)) {
              arr_val <- child[[j]]
              k <- k + 1L
              if (k > length(r_uid)) {
                r_uid   <- c(r_uid, integer(length(r_uid)))
                r_org   <- c(r_org, character(length(r_org)))
                r_ctype <- c(r_ctype, character(length(r_ctype)))
                r_ts    <- c(r_ts, character(length(r_ts)))
                r_op    <- c(r_op, character(length(r_op)))
                r_field <- c(r_field, character(length(r_field)))
                r_val   <- c(r_val, character(length(r_val)))
              }
              r_uid[k] <- uid; r_org[k] <- org; r_ctype[k] <- ctype; r_ts[k] <- ts
              r_op[k] <- op
              r_field[k] <- paste0(gsub("/", "_", child_path), "_", j - 1L)
              r_val[k] <- if (is.null(arr_val)) NA_character_ else as.character(arr_val)
            }
          } else {
            k <- k + 1L
            if (k > length(r_uid)) {
              r_uid   <- c(r_uid, integer(length(r_uid)))
              r_org   <- c(r_org, character(length(r_org)))
              r_ctype <- c(r_ctype, character(length(r_ctype)))
              r_ts    <- c(r_ts, character(length(r_ts)))
              r_op    <- c(r_op, character(length(r_op)))
              r_field <- c(r_field, character(length(r_field)))
              r_val   <- c(r_val, character(length(r_val)))
            }
            r_uid[k] <- uid; r_org[k] <- org; r_ctype[k] <- ctype; r_ts[k] <- ts
            r_op[k] <- op; r_field[k] <- gsub("/", "_", child_path)
            r_val[k] <- as.character(child)
          }
        }
        next
      }

      if (is.list(val) && is.null(names(val))) {
        for (j in seq_along(val)) {
          arr_val <- val[[j]]
          k <- k + 1L
          if (k > length(r_uid)) {
            r_uid   <- c(r_uid, integer(length(r_uid)))
            r_org   <- c(r_org, character(length(r_org)))
            r_ctype <- c(r_ctype, character(length(r_ctype)))
            r_ts    <- c(r_ts, character(length(r_ts)))
            r_op    <- c(r_op, character(length(r_op)))
            r_field <- c(r_field, character(length(r_field)))
            r_val   <- c(r_val, character(length(r_val)))
          }
          r_uid[k] <- uid; r_org[k] <- org; r_ctype[k] <- ctype; r_ts[k] <- ts
          r_op[k] <- op
          r_field[k] <- paste0(gsub("/", "_", path), "_", j - 1L)
          r_val[k] <- if (is.null(arr_val)) NA_character_ else as.character(arr_val)
        }
        next
      }
    }
  }

  if (k == 0L) {
    return(tibble::tibble(
      update_id = integer(), org_nr = character(),
      change_type = character(), timestamp = as.POSIXct(character()),
      operation = character(), field = character(),
      new_value = character()
    ))
  }

  s <- seq_len(k)
  tibble::tibble(
    update_id   = r_uid[s],
    org_nr      = r_org[s],
    change_type = r_ctype[s],
    timestamp   = as.POSIXct(r_ts[s], format = "%Y-%m-%dT%H:%M:%OS"),
    operation   = r_op[s],
    field       = r_field[s],
    new_value   = r_val[s]
  )
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
#' Collector-based, non-recursive for the common cases (scalar, remove).
#' Falls back to [flatten_value_into()] only for nested objects/arrays.
#' Used by [parse_updates_page()] and the sync engine.
#'
#' @param endringer List of patch operations from the brreg API.
#' @returns A tibble with columns `operation`, `field`, `new_value`.
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
