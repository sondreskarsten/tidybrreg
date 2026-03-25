#' Synchronize local state with the brreg CDC stream
#'
#' Maintains a local mirror of the Enhetsregisteret by applying
#' incremental CDC (change data capture) events to a persistent
#' state table. On first run, bootstraps from a bulk download.
#' Subsequent runs poll the CDC endpoints from the last cursor
#' position and apply mutations.
#'
#' Four state files are maintained:
#' - `enheter.parquet` — main entities (~1M rows)
#' - `underenheter.parquet` — sub-entities (~500K rows)
#' - `roller.parquet` — all roles (~4.5M rows)
#' - `paategninger.parquet` — registry annotations
#'
#' Every mutation is logged to a Hive-partitioned changelog
#' under `state/changelog/sync_date={date}/`. The changelog
#' drives [brreg_changes()] and [brreg_flows()].
#'
#' @section Write ordering:
#' Changelog is written first (WAL), then state files, then
#' cursor. If a crash occurs between state and cursor, the
#' next sync replays from the old cursor. Mutations are
#' idempotent (upsert by org_nr), so replay is safe.
#'
#' @param types Character vector of streams to sync. Default
#'   syncs all four.
#' @param size Integer. CDC page size per API call (max 10000).
#' @param roller_method One of `"bulk"` (default) or `"cdc"`.
#'   `"bulk"` downloads the full totalbestand (~131 MB) and
#'   computes a field-level diff against previous state — fast
#'   and produces granular changelogs. `"cdc"` fetches current
#'   roles per-org via the API for each CDC event — slower but
#'   provides sub-daily attribution when syncing multiple times
#'   per day.
#' @param verbose Logical. Print progress messages.
#'
#' @returns A list with sync summary: events processed per type,
#'   changelog rows written, elapsed time.
#'
#' @family tidybrreg data management functions
#' @seealso [brreg_sync_status()] to check current state,
#'   [brreg_changes()] to query the changelog,
#'   [brreg_flows()] for entry/exit counts.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' brreg_sync()
#' brreg_sync_status()
#' }
brreg_sync <- function(types = c("enheter", "underenheter", "roller"),
                        size = 10000L,
                        roller_method = c("bulk", "cdc"),
                        verbose = TRUE) {
  types <- match.arg(types, c("enheter", "underenheter", "roller"),
                      several.ok = TRUE)
  roller_method <- match.arg(roller_method)
  check_parquet_available()
  t0 <- Sys.time()

  needs_bootstrap <- !all(vapply(types, has_state, logical(1)))
  if (needs_bootstrap) {
    if (verbose) cli::cli_h2("Bootstrapping state from bulk download")
    bootstrap_state(types, verbose = verbose)
  }

  cursor <- read_cursor()
  summary <- list()
  all_changelog <- list()

  for (type in types) {
    if (verbose) cli::cli_h3("Syncing {type}")
    result <- sync_one_type(type, cursor, size = size,
                             roller_method = roller_method, verbose = verbose)
    cursor[[paste0(type, "_id")]] <- result$new_cursor_id
    summary[[type]] <- result$summary
    if (!is.null(result$changelog) && nrow(result$changelog) > 0) {
      all_changelog <- c(all_changelog, list(result$changelog))
    }
  }

  changelog <- dplyr::bind_rows(all_changelog)

  if (nrow(changelog) > 0) {
    write_changelog(changelog)
  }

  for (type in types) {
    if (!is.null(summary[[type]]$state)) {
      write_state(summary[[type]]$state, type)
    }
    if (!is.null(summary[[type]]$paategninger_state)) {
      write_state(summary[[type]]$paategninger_state, "paategninger")
    }
  }

  write_cursor(cursor)

  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  if (verbose) {
    cli::cli_h2("Sync complete ({round(elapsed, 1)}s)")
    cli::cli_text("Changelog: {nrow(changelog)} rows")
    for (type in types) {
      s <- summary[[type]]
      cli::cli_text("  {type}: {s$n_events} events ({s$n_ny} new, {s$n_slett} deleted, {s$n_endring} changed)")
    }
  }

  invisible(list(
    summary = summary,
    changelog_rows = nrow(changelog),
    elapsed = elapsed
  ))
}


#' Bootstrap state from bulk download
#' @keywords internal
bootstrap_state <- function(types, verbose = TRUE) {
  for (type in types) {
    if (has_state(type)) next
    if (verbose) cli::cli_alert_info("Downloading {type} bulk data...")
    df <- brreg_download(type = type, type_output = "tibble")

    if (type == "enheter") {
      paat <- extract_paategninger(df)
      if (!is.null(paat) && nrow(paat) > 0) {
        write_state(paat, "paategninger")
      } else {
        write_state(empty_paategninger(), "paategninger")
      }
    }

    write_state(df, type)
    if (verbose) cli::cli_alert_success("{type}: {format(nrow(df), big.mark = ',')} rows")
  }
}


#' Sync one CDC stream
#' @param roller_method Passed from [brreg_sync()]. Controls roller
#'   sync strategy: `"bulk"` (totalbestand diff) or `"cdc"` (per-org).
#' @keywords internal
sync_one_type <- function(type, cursor, size = 10000L,
                           roller_method = "bulk", verbose = TRUE) {
  cursor_id <- cursor[[paste0(type, "_id")]]

  if (type == "roller" && roller_method == "bulk") {
    updates <- paginate_cdc_bounded(cursor_id, size = size, verbose = verbose)
  } else {
    updates <- paginate_cdc(type, cursor_id, size = size, verbose = verbose)
  }

  if (is.null(updates) || nrow(updates) == 0) {
    if (verbose) cli::cli_alert_info("No new events")
    return(list(
      new_cursor_id = cursor_id,
      summary = list(n_events = 0L, n_ny = 0L, n_slett = 0L,
                      n_endring = 0L, state = NULL,
                      paategninger_state = NULL),
      changelog = NULL
    ))
  }

  new_cursor_id <- max(updates$update_id)
  if (verbose) cli::cli_alert_info("{nrow(updates)} events (cursor {cursor_id} -> {new_cursor_id})")

  state <- read_state(type, use_cache = FALSE)
  paat_state <- if (type == "enheter") read_state("paategninger", use_cache = FALSE) else NULL

  changelog <- list()

  if (type == "roller") {
    if (roller_method == "bulk") {
      result <- apply_roller_events(state, updates, verbose = verbose)
    } else {
      result <- apply_roller_events_cdc(state, updates, verbose = verbose)
    }
    state <- result$state
    changelog <- c(changelog, list(result$changelog))
  } else {
    ny <- updates[updates$change_type == "Ny", ]
    slett <- updates[updates$change_type %in% c("Sletting", "Fjernet"), ]
    endring <- updates[updates$change_type == "Endring", ]

    if (nrow(ny) > 0) {
      result <- apply_ny_events(state, ny, type)
      state <- result$state
      changelog <- c(changelog, list(result$changelog))
    }

    if (nrow(endring) > 0) {
      result <- apply_endring_events(state, paat_state, endring, type)
      state <- result$state
      paat_state <- result$paat_state
      changelog <- c(changelog, list(result$changelog))
    }

    if (nrow(slett) > 0) {
      result <- apply_slett_events(state, paat_state, slett, type)
      state <- result$state
      paat_state <- result$paat_state
      changelog <- c(changelog, list(result$changelog))
    }
  }

  n_ny <- if (type != "roller") nrow(updates[updates$change_type == "Ny", ]) else 0L
  n_slett <- if (type != "roller") nrow(updates[updates$change_type %in% c("Sletting", "Fjernet"), ]) else 0L
  n_endring <- if (type != "roller") nrow(updates[updates$change_type == "Endring", ]) else nrow(updates)

  list(
    new_cursor_id = new_cursor_id,
    summary = list(
      n_events = nrow(updates),
      n_ny = n_ny,
      n_slett = n_slett,
      n_endring = n_endring,
      state = state,
      paategninger_state = paat_state
    ),
    changelog = dplyr::bind_rows(changelog)
  )
}


#' Parse a page of raw CDC objects for the sync path (stores raw endringer)
#' @keywords internal
parse_sync_page <- function(raw_updates) {
  n <- length(raw_updates)
  ids <- integer(n)
  orgs <- character(n)
  types <- character(n)
  timestamps <- character(n)
  raw_changes <- vector("list", n)

  for (i in seq_len(n)) {
    u <- raw_updates[[i]]
    ids[i] <- u$oppdateringsid %||% NA_integer_
    orgs[i] <- u$organisasjonsnummer %||% NA_character_
    types[i] <- u$endringstype %||% NA_character_
    timestamps[i] <- u$dato %||% NA_character_
    raw_changes[[i]] <- if (!is.null(u$endringer) && length(u$endringer) > 0) {
      u$endringer
    } else {
      NULL
    }
  }

  tibble::tibble(
    update_id   = ids,
    org_nr      = orgs,
    change_type = types,
    timestamp   = timestamps,
    endringer   = raw_changes
  )
}


#' Paginate roller CDC with bounded page count
#'
#' For `roller_method = "bulk"`, the CDC poll is only used for
#' cursor advancement and per-org timestamp enrichment. The bulk
#' totalbestand diff covers all changes regardless of CDC events.
#' This function caps pagination at `max_pages` to avoid fetching
#' the entire CDC history on first bootstrap (cursor_id = 0).
#'
#' @param from_id Cursor position.
#' @param size Page size.
#' @param max_pages Hard cap on pages (default 5 = 50K events).
#' @param verbose Print progress.
#' @returns Tibble of CDC events, or empty tibble.
#' @keywords internal
paginate_cdc_bounded <- function(from_id, size = 10000L,
                                  max_pages = 5L, verbose = TRUE) {
  all_updates <- list()
  current_id <- from_id
  page <- 0L

  repeat {
    page <- page + 1L
    if (page > max_pages) {
      if (verbose) cli::cli_alert_info("Bulk roller: capped CDC poll at {max_pages} pages")
      break
    }

    query <- list(afterId = current_id, size = size)
    resp <- brreg_req("oppdateringer/roller") |>
      httr2::req_url_query(!!!query) |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform()

    if (httr2::resp_status(resp) >= 400L) break
    events <- httr2::resp_body_json(resp)
    if (length(events) == 0) break

    updates <- dplyr::bind_rows(lapply(events, function(e) {
      tibble::tibble(
        update_id   = as.integer(e$id %||% NA),
        org_nr      = e$data$organisasjonsnummer %||% NA_character_,
        change_type = sub(".*\\.", "", e$type %||% ""),
        timestamp   = e$time %||% NA_character_,
        endringer   = list(NULL)
      )
    }))

    if (is.null(updates) || nrow(updates) == 0) break
    all_updates <- c(all_updates, list(updates))
    current_id <- max(updates$update_id)
    if (verbose && page > 1) cli::cli_alert_info("  page {page}: {nrow(updates)} events")
    if (nrow(updates) < size) break
  }

  if (length(all_updates) == 0) return(tibble::tibble())
  dplyr::bind_rows(all_updates)
}


#' Paginate through CDC events from cursor position
#' @keywords internal
paginate_cdc <- function(type, from_id, size = 10000L, verbose = TRUE) {
  all_updates <- list()
  current_id <- from_id
  page <- 0L

  repeat {
    page <- page + 1L
    if (type == "roller") {
      query <- list(afterId = current_id, size = size)

      resp <- brreg_req("oppdateringer/roller") |>
        httr2::req_url_query(!!!query) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_perform()

      if (httr2::resp_status(resp) >= 400L) break

      events <- httr2::resp_body_json(resp)
      if (length(events) == 0) break

      updates <- dplyr::bind_rows(lapply(events, function(e) {
        tibble::tibble(
          update_id   = as.integer(e$id %||% NA),
          org_nr      = e$data$organisasjonsnummer %||% NA_character_,
          change_type = sub(".*\\.", "", e$type %||% ""),
          timestamp   = e$time %||% NA_character_,
          endringer   = list(NULL)
        )
      }))
    } else {
      query <- list(oppdateringsid = current_id + 1L, size = size)

      resp <- brreg_req(paste0("oppdateringer/", type)) |>
        httr2::req_url_query(!!!query) |>
        httr2::req_url_query(includeChanges = "true") |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_perform()

      if (httr2::resp_status(resp) >= 400L) break

      body <- httr2::resp_body_json(resp)
      key <- paste0("oppdaterte", tools::toTitleCase(type))
      raw_updates <- body[["_embedded"]][[key]]
      if (is.null(raw_updates) || length(raw_updates) == 0) break

      updates <- parse_sync_page(raw_updates)
    }

    if (is.null(updates) || nrow(updates) == 0) break
    all_updates <- c(all_updates, list(updates))
    current_id <- max(updates$update_id)
    if (verbose && page > 1) cli::cli_alert_info("  page {page}: {nrow(updates)} events")
    if (nrow(updates) < size) break
  }

  if (length(all_updates) == 0) return(tibble::tibble())
  dplyr::bind_rows(all_updates)
}


#' Apply Ny (new entity) events to state
#' @keywords internal
apply_ny_events <- function(state, ny_events, type) {
  changelog <- list()

  for (i in seq_len(nrow(ny_events))) {
    row <- ny_events[i, ]
    entity <- tryCatch(
      brreg_entity(row$org_nr, registry = type),
      error = function(e) NULL
    )
    if (is.null(entity) || nrow(entity) == 0) next
    if ("deleted" %in% names(entity) && isTRUE(entity$deleted)) next

    common_cols <- intersect(names(state), names(entity))
    entity_row <- entity[1, common_cols, drop = FALSE]
    missing_cols <- setdiff(names(state), common_cols)
    for (col in missing_cols) {
      entity_row[[col]] <- NA
    }
    entity_row <- entity_row[, names(state), drop = FALSE]

    state <- state[state$org_nr != row$org_nr, ]
    state <- dplyr::bind_rows(state, entity_row)

    changelog <- c(changelog, list(tibble::tibble(
      timestamp   = row$timestamp,
      org_nr      = row$org_nr,
      registry    = type,
      change_type = "entry",
      field       = NA_character_,
      value_from  = NA_character_,
      value_to    = NA_character_,
      update_id   = row$update_id
    )))
  }

  list(state = state, changelog = dplyr::bind_rows(changelog))
}


#' Apply Endring (change) events to state
#' @keywords internal
apply_endring_events <- function(state, paat_state, endring_events, type) {
  cl_ts <- character(nrow(endring_events) * 10L)
  cl_org <- character(length(cl_ts))
  cl_reg <- character(length(cl_ts))
  cl_ct <- character(length(cl_ts))
  cl_field <- character(length(cl_ts))
  cl_from <- character(length(cl_ts))
  cl_to <- character(length(cl_ts))
  cl_uid <- integer(length(cl_ts))
  cl_k <- 0L

  grow_cl <- function() {
    n <- length(cl_ts)
    cl_ts <<- c(cl_ts, character(n))
    cl_org <<- c(cl_org, character(n))
    cl_reg <<- c(cl_reg, character(n))
    cl_ct <<- c(cl_ct, character(n))
    cl_field <<- c(cl_field, character(n))
    cl_from <<- c(cl_from, character(n))
    cl_to <<- c(cl_to, character(n))
    cl_uid <<- c(cl_uid, integer(n))
  }

  emit_cl <- function(ts, org, reg, ct, fld, vfrom, vto, uid) {
    cl_k <<- cl_k + 1L
    if (cl_k > length(cl_ts)) grow_cl()
    cl_ts[cl_k] <<- ts
    cl_org[cl_k] <<- org
    cl_reg[cl_k] <<- reg
    cl_ct[cl_k] <<- ct
    cl_field[cl_k] <<- fld
    cl_from[cl_k] <<- vfrom
    cl_to[cl_k] <<- vto
    cl_uid[cl_k] <<- uid
  }

  for (i in seq_len(nrow(endring_events))) {
    row <- endring_events[i, ]
    patches_raw <- row$endringer[[1]]
    if (is.null(patches_raw) || length(patches_raw) == 0) next

    parsed <- parse_patch(patches_raw)
    if (nrow(parsed) == 0) next

    paat_patches <- parsed[grepl("^paategninger", parsed$field), ]
    field_patches <- parsed[!grepl("^paategninger", parsed$field), ]

    if (nrow(paat_patches) > 0 && !is.null(paat_state) && type == "enheter") {
      result <- apply_paategning_patches(paat_state, row$org_nr,
                                          paat_patches, row$timestamp,
                                          row$update_id)
      paat_state <- result$state
      if (nrow(result$changelog) > 0) {
        for (j in seq_len(nrow(result$changelog))) {
          r <- result$changelog[j, ]
          emit_cl(r$timestamp, r$org_nr, r$registry, r$change_type,
                  r$field, r$value_from, r$value_to, r$update_id)
        }
      }
    }

    if (nrow(field_patches) == 0) next

    idx <- which(state$org_nr == row$org_nr)
    if (length(idx) == 0) next
    idx <- idx[1]

    for (j in seq_len(nrow(field_patches))) {
      p <- field_patches[j, ]
      col <- find_state_column(p$field, names(state))
      if (is.null(col)) next

      if (p$operation == "remove") {
        old_val <- as.character(state[[col]][idx])
        state[[col]][idx] <- NA
        emit_cl(row$timestamp, row$org_nr, type, "change",
                col, old_val, NA_character_, row$update_id)
        next
      }

      old_val <- as.character(state[[col]][idx])
      new_val <- p$new_value

      if (!identical(old_val, new_val)) {
        if (is.integer(state[[col]])) {
          state[[col]][idx] <- suppressWarnings(as.integer(new_val))
        } else if (is.logical(state[[col]])) {
          state[[col]][idx] <- as.logical(new_val)
        } else if (is.numeric(state[[col]])) {
          state[[col]][idx] <- suppressWarnings(as.numeric(new_val))
        } else {
          state[[col]][idx] <- new_val
        }
        emit_cl(row$timestamp, row$org_nr, type, "change",
                col, old_val, new_val, row$update_id)
      }
    }
  }

  changelog <- if (cl_k > 0L) {
    tibble::tibble(
      timestamp   = cl_ts[seq_len(cl_k)],
      org_nr      = cl_org[seq_len(cl_k)],
      registry    = cl_reg[seq_len(cl_k)],
      change_type = cl_ct[seq_len(cl_k)],
      field       = cl_field[seq_len(cl_k)],
      value_from  = cl_from[seq_len(cl_k)],
      value_to    = cl_to[seq_len(cl_k)],
      update_id   = cl_uid[seq_len(cl_k)]
    )
  } else {
    tibble::tibble(
      timestamp = character(), org_nr = character(),
      registry = character(), change_type = character(),
      field = character(), value_from = character(),
      value_to = character(), update_id = integer()
    )
  }

  list(state = state, paat_state = paat_state, changelog = changelog)
}


#' Apply Sletting/Fjernet events to state
#' @keywords internal
apply_slett_events <- function(state, paat_state, slett_events, type) {
  changelog <- dplyr::bind_rows(lapply(seq_len(nrow(slett_events)), function(i) {
    row <- slett_events[i, ]
    tibble::tibble(
      timestamp = row$timestamp, org_nr = row$org_nr,
      registry = type, change_type = "exit",
      field = NA_character_, value_from = NA_character_,
      value_to = NA_character_, update_id = row$update_id
    )
  }))

  deleted_orgs <- slett_events$org_nr
  state <- state[!state$org_nr %in% deleted_orgs, ]

  if (!is.null(paat_state) && type == "enheter") {
    paat_state <- paat_state[!paat_state$org_nr %in% deleted_orgs, ]
  }

  list(state = state, paat_state = paat_state, changelog = changelog)
}


#' Apply roller CDC events to state
#'
#' Roller events are bare notifications (`rolle.oppdatert` with only
#' org_nr). For each unique affected org_nr, fetches current roles
#' via API, diffs against stored state, and logs changes.
#'
#' @keywords internal
apply_roller_events <- function(state, updates, verbose = TRUE) {
  affected_orgs <- unique(updates$org_nr)
  if (verbose) {
    cli::cli_alert_info(
      "{length(affected_orgs)} entities with role changes \u2014 downloading totalbestand for bulk diff"
    )
  }

  new_state <- brreg_download("roller", refresh = TRUE, type_output = "tibble")
  if (verbose) cli::cli_alert_success("Downloaded {nrow(new_state)} role records")

  event_map <- updates |>
    dplyr::summarise(
      timestamp = max(.data$timestamp, na.rm = TRUE),
      update_id = max(.data$update_id, na.rm = TRUE),
      .by = "org_nr"
    )

  default_ts <- updates$timestamp[nrow(updates)]
  default_id <- max(updates$update_id)

  changelog <- diff_roller_state(
    old_state  = state,
    new_state  = new_state,
    timestamp  = default_ts,
    update_id  = default_id
  )

  if (nrow(changelog) > 0 && nrow(event_map) > 0) {
    changelog <- dplyr::rows_update(
      changelog, event_map,
      by = "org_nr", unmatched = "ignore"
    )
  }

  if (verbose && nrow(changelog) > 0) {
    n_orgs <- dplyr::n_distinct(changelog$org_nr)
    summary_label <- changelog |>
      dplyr::count(.data$change_type) |>
      dplyr::mutate(label = paste0(.data$change_type, "=", .data$n)) |>
      dplyr::pull("label") |>
      paste(collapse = ", ")
    cli::cli_alert_success("{nrow(changelog)} changelog rows across {n_orgs} orgs ({summary_label})")
  }

  list(state = new_state, changelog = changelog)
}


#' Apply roller CDC events via per-org API re-fetch (legacy fallback)
#'
#' Fetches current roles for each affected org via [brreg_roles()].
#' Produces field-level changelogs using [diff_roller_state()] on a
#' per-org basis. Slower than [apply_roller_events()] (bulk method)
#' but provides per-event timestamp attribution for sub-daily syncs.
#'
#' @param state Current roller state tibble.
#' @param updates Tibble of CDC events with `org_nr`, `timestamp`,
#'   `update_id`.
#' @param verbose Logical.
#' @returns List with `state` and `changelog`.
#' @keywords internal
apply_roller_events_cdc <- function(state, updates, verbose = TRUE) {
  affected_orgs <- unique(updates$org_nr)
  if (verbose) {
    cli::cli_alert_info(
      "{length(affected_orgs)} entities \u2014 fetching roles per-org (cdc method)"
    )
  }

  all_changelog <- list()
  removed_orgs <- character()
  new_rows <- list()

  for (org in affected_orgs) {
    event_row <- updates[updates$org_nr == org, ][1, ]

    new_roles <- tryCatch(
      brreg_roles(org),
      error = function(e) NULL
    )

    old_roles <- state[state$org_nr == org, ]
    new_roles_safe <- if (!is.null(new_roles) && nrow(new_roles) > 0) {
      new_roles
    } else {
      tibble::tibble()
    }

    if (nrow(old_roles) == 0 && nrow(new_roles_safe) == 0) next

    cl <- diff_roller_state(
      old_state  = if (nrow(old_roles) > 0) old_roles else NULL,
      new_state  = new_roles_safe,
      timestamp  = event_row$timestamp,
      update_id  = event_row$update_id
    )
    if (nrow(cl) > 0) all_changelog <- c(all_changelog, list(cl))

    removed_orgs <- c(removed_orgs, org)
    if (nrow(new_roles_safe) > 0) {
      common_cols <- intersect(names(state), names(new_roles_safe))
      new_rows <- c(new_rows, list(new_roles_safe[, common_cols, drop = FALSE]))
    }
  }

  state <- state[!state$org_nr %in% removed_orgs, ]
  if (length(new_rows) > 0) {
    state <- dplyr::bind_rows(state, dplyr::bind_rows(new_rows))
  }

  list(state = state, changelog = dplyr::bind_rows(all_changelog))
}


#' Map a flattened CDC field name to a state column
#'
#' Handles the many-to-one mapping from CDC patch paths to
#' tidybrreg column names. Uses `field_dict` when available,
#' falls back to direct matching.
#'
#' @param cdc_field Character. The flattened field from `parse_patch`.
#' @param state_cols Character vector of column names in the state table.
#' @returns Column name or `NULL` if no match.
#' @keywords internal
find_state_column <- function(cdc_field, state_cols) {
  cdc_to_col <- c(
    # NACE codes (both parent-level and _kode sub-path)
    "naeringskode1"                         = "nace_1",
    "naeringskode1_kode"                    = "nace_1",
    "naeringskode1_beskrivelse"             = "nace_1_desc",
    "naeringskode2"                         = "nace_2",
    "naeringskode2_kode"                    = "nace_2",
    "naeringskode2_beskrivelse"             = "nace_2_desc",
    "naeringskode3"                         = "nace_3",
    "naeringskode3_kode"                    = "nace_3",
    "naeringskode3_beskrivelse"             = "nace_3_desc",

    # Business address (forretningsadresse)
    "forretningsadresse_kommunenummer"      = "municipality_code",
    "forretningsadresse_kommune"            = "municipality",
    "forretningsadresse_postnummer"         = "business_postcode",
    "forretningsadresse_poststed"           = "business_city",
    "forretningsadresse_landkode"           = "country_code",
    "forretningsadresse_land"               = "country",
    "forretningsadresse_adresse_0"          = "business_address",
    "forretningsadresse_adresse_1"          = "business_address",

    # Location address (underenheter)
    "beliggenhetsadresse_kommunenummer"     = "location_municipality_code",
    "beliggenhetsadresse_kommune"           = "location_municipality",
    "beliggenhetsadresse_postnummer"        = "location_postcode",
    "beliggenhetsadresse_poststed"          = "location_city",
    "beliggenhetsadresse_landkode"          = "location_country_code",
    "beliggenhetsadresse_land"              = "location_country",
    "beliggenhetsadresse_adresse_0"         = "location_address",
    "beliggenhetsadresse_adresse_1"         = "location_address",

    # Postal address
    "postadresse_adresse_0"                 = "postal_address",
    "postadresse_adresse_1"                 = "postal_address",
    "postadresse_postnummer"                = "postal_postcode",
    "postadresse_poststed"                  = "postal_city",
    "postadresse_kommunenummer"             = "postal_municipality_code",
    "postadresse_kommune"                   = "postal_municipality",
    "postadresse_landkode"                  = "postal_country_code",
    "postadresse_land"                      = "postal_country",

    # Legal form / sector (both parent-level and _kode sub-path)
    "organisasjonsform"                     = "legal_form",
    "organisasjonsform_kode"                = "legal_form",
    "organisasjonsform_beskrivelse"         = "legal_form_desc",
    "institusjonellSektorkode"              = "sector_code",
    "institusjonellSektorkode_kode"         = "sector_code",
    "institusjonellSektorkode_beskrivelse"  = "sector_desc",

    # Employees
    "antallAnsatte"                         = "employees",
    "harRegistrertAntallAnsatte"            = "employees_reported",

    # Registration dates
    "registreringsdatoEnhetsregisteret"     = "registration_date",
    "registreringsdatoForetaksregisteret"   = "business_register_date",

    # Register membership flags
    "registrertIForetaksregisteret"         = "in_business_register",
    "registrertIFrivillighetsregisteret"    = "in_nonprofit_register",
    "registrertIMvaregisteret"              = "vat_registered",
    "registrertIStiftelsesregisteret"       = "in_foundation_register",
    "registrertIPartiregisteret"            = "registrert_ipartiregisteret",

    # Core entity fields
    "konkurs"                               = "bankrupt",
    "konkursdato"                           = "bankruptcy_date",
    "underAvvikling"                        = "in_liquidation",
    "underAvviklingDato"                    = "liquidation_date",
    "underTvangsavviklingEllerTvangsopplosning" = "forced_dissolution",
    "navn"                                  = "name",
    "stiftelsesdato"                        = "founding_date",
    "vedtektsdato"                          = "articles_date",
    "sisteInnsendteAarsregnskap"            = "last_annual_accounts",
    "erIKonsern"                            = "in_corporate_group",
    "maalform"                              = "language_form",
    "overordnetEnhet"                       = "parent_org_nr",
    "slettedato"                            = "deletion_date",
    "datoEierskifte"                        = "ownership_change_date",
    "aktivitet"                             = "activity",

    # Contact info
    "epostadresse"                          = "epostadresse",
    "hjemmeside"                            = "website",
    "telefon"                               = "telefon",
    "mobil"                                 = "mobil",

    # Audit exemption
    "fravalgRevisjonDato"                   = "audit_exemption_date",
    "fravalgRevisjonBeslutningsDato"        = "audit_exemption_decision_date",

    # Additional registration dates
    "registreringsdatoMerverdiavgiftsregisteretEnhetsregisteret" = "vat_registration_date_er",
    "registreringsdatoAntallAnsatteEnhetsregisteret"  = "employee_reg_date_er",
    "registreringsdatoAntallAnsatteNavAaregisteret"   = "employee_reg_date_nav",

    # Underenhet start date
    "oppstartsdato"                         = "start_date",

    # Party register
    "registrertIPartiregisteret"            = "in_party_register"
  )

  mapped <- cdc_to_col[cdc_field]
  if (!is.na(mapped) && mapped %in% state_cols) return(unname(mapped))

  if (cdc_field %in% state_cols) return(cdc_field)

  NULL
}


#' Apply påtegning-specific patches to the annotations state
#' @keywords internal
apply_paategning_patches <- function(paat_state, org_nr, patches,
                                      timestamp, update_id) {
  changelog <- list()

  full_clear <- any(patches$field == "paategninger" & patches$operation %in% c("replace", "remove") &
                      is.na(patches$new_value))
  if (full_clear) {
    existing <- paat_state[paat_state$org_nr == org_nr, ]
    if (nrow(existing) > 0) {
      changelog <- c(changelog, list(tibble::tibble(
        timestamp = timestamp, org_nr = org_nr,
        registry = "paategninger", change_type = "annotation_cleared",
        field = "paategninger", value_from = as.character(nrow(existing)),
        value_to = "0", update_id = update_id
      )))
    }
    paat_state <- paat_state[paat_state$org_nr != org_nr, ]
    return(list(state = paat_state, changelog = dplyr::bind_rows(changelog)))
  }

  append_rows <- patches[grepl("^paategninger_-_", patches$field), ]
  if (nrow(append_rows) > 0) {
    infotype <- append_rows$new_value[append_rows$field == "paategninger_-_infotype"]
    tekst <- append_rows$new_value[append_rows$field == "paategninger_-_tekst"]
    dato <- append_rows$new_value[append_rows$field == "paategninger_-_innfoertDato"]

    if (length(infotype) > 0) {
      existing_n <- sum(paat_state$org_nr == org_nr)
      new_row <- tibble::tibble(
        org_nr       = org_nr,
        position     = existing_n,
        infotype     = infotype[1],
        tekst        = if (length(tekst) > 0) tekst[1] else NA_character_,
        innfoert_dato = if (length(dato) > 0) dato[1] else NA_character_
      )
      paat_state <- dplyr::bind_rows(paat_state, new_row)

      changelog <- c(changelog, list(tibble::tibble(
        timestamp = timestamp, org_nr = org_nr,
        registry = "paategninger", change_type = "annotation_added",
        field = infotype[1],
        value_from = NA_character_,
        value_to = if (length(tekst) > 0) tekst[1] else NA_character_,
        update_id = update_id
      )))
    }
  }

  list(state = paat_state, changelog = dplyr::bind_rows(changelog))
}


#' Extract påtegninger from bulk entity data into separate table
#' @keywords internal
extract_paategninger <- function(entities) {
  if (!"paategninger" %in% names(entities)) return(empty_paategninger())

  has_paat <- !is.na(entities$paategninger) & entities$paategninger != ""
  if (!any(has_paat)) return(empty_paategninger())

  paat_entities <- entities[has_paat, , drop = FALSE]
  rows <- vector("list", sum(has_paat))

  for (i in seq_len(nrow(paat_entities))) {
    org <- paat_entities$org_nr[i]
    raw <- paat_entities$paategninger[i]

    parsed <- tryCatch(
      jsonlite::fromJSON(raw, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(parsed)) next

    # Handle both list-of-lists (JSON array) and single object
    if (!is.null(names(parsed))) parsed <- list(parsed)

    for (j in seq_along(parsed)) {
      p <- parsed[[j]]
      rows[[length(rows) + 1L]] <- tibble::tibble(
        org_nr        = org,
        position      = j - 1L,
        infotype      = p$infotype %||% NA_character_,
        tekst         = p$tekst %||% NA_character_,
        innfoert_dato = p$innfoertDato %||% NA_character_
      )
    }
  }

  result <- dplyr::bind_rows(rows)
  if (nrow(result) == 0) return(empty_paategninger())
  result
}


#' Empty påtegninger tibble
#' @keywords internal
empty_paategninger <- function() {
  tibble::tibble(
    org_nr        = character(),
    position      = integer(),
    infotype      = character(),
    tekst         = character(),
    innfoert_dato = character()
  )
}
