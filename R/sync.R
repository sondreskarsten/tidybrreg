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
                        verbose = TRUE) {
  types <- match.arg(types, c("enheter", "underenheter", "roller"),
                      several.ok = TRUE)
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
    result <- sync_one_type(type, cursor, size = size, verbose = verbose)
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
#' @keywords internal
sync_one_type <- function(type, cursor, size = 10000L, verbose = TRUE) {
  cursor_id <- cursor[[paste0(type, "_id")]]

  updates <- paginate_cdc(type, cursor_id, size = size, verbose = verbose)

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
    result <- apply_roller_events(state, updates, verbose = verbose)
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

      updates <- dplyr::bind_rows(lapply(raw_updates, function(u) {
        base <- tibble::tibble(
          update_id   = u$oppdateringsid,
          org_nr      = u$organisasjonsnummer,
          change_type = u$endringstype,
          timestamp   = u$dato
        )
        if (!is.null(u$endringer) && length(u$endringer) > 0) {
          base$endringer <- list(u$endringer)
        } else {
          base$endringer <- list(NULL)
        }
        base
      }))
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
  changelog <- list()

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
      changelog <- c(changelog, list(result$changelog))
    }

    if (nrow(field_patches) == 0) next

    idx <- which(state$org_nr == row$org_nr)
    if (length(idx) == 0) next
    idx <- idx[1]

    for (j in seq_len(nrow(field_patches))) {
      p <- field_patches[j, ]
      if (p$operation == "remove") {
        col <- find_state_column(p$field, names(state))
        if (!is.null(col)) {
          old_val <- as.character(state[[col]][idx])
          state[[col]][idx] <- NA
          changelog <- c(changelog, list(tibble::tibble(
            timestamp = row$timestamp, org_nr = row$org_nr,
            registry = type, change_type = "change",
            field = col, value_from = old_val,
            value_to = NA_character_, update_id = row$update_id
          )))
        }
        next
      }

      col <- find_state_column(p$field, names(state))
      if (is.null(col)) next

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

        changelog <- c(changelog, list(tibble::tibble(
          timestamp = row$timestamp, org_nr = row$org_nr,
          registry = type, change_type = "change",
          field = col, value_from = old_val,
          value_to = new_val, update_id = row$update_id
        )))
      }
    }
  }

  list(state = state, paat_state = paat_state,
       changelog = dplyr::bind_rows(changelog))
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
  if (verbose) cli::cli_alert_info("{length(affected_orgs)} unique entities with role changes")

  changelog <- list()
  removed_orgs <- character()
  new_rows <- list()

  for (org in affected_orgs) {
    event_row <- updates[updates$org_nr == org, ][1, ]

    new_roles <- tryCatch(
      brreg_roles(org),
      error = function(e) NULL
    )

    old_roles <- state[state$org_nr == org, ]
    old_n <- nrow(old_roles)
    new_n <- if (!is.null(new_roles)) nrow(new_roles) else 0L

    if (old_n != new_n) {
      changelog <- c(changelog, list(tibble::tibble(
        timestamp = event_row$timestamp, org_nr = org,
        registry = "roller", change_type = "change",
        field = "role_count",
        value_from = as.character(old_n),
        value_to = as.character(new_n),
        update_id = event_row$update_id
      )))
    }

    removed_orgs <- c(removed_orgs, org)
    if (!is.null(new_roles) && new_n > 0) {
      common_cols <- intersect(names(state), names(new_roles))
      new_rows <- c(new_rows, list(new_roles[, common_cols, drop = FALSE]))
    }
  }

  state <- state[!state$org_nr %in% removed_orgs, ]
  if (length(new_rows) > 0) {
    state <- dplyr::bind_rows(state, dplyr::bind_rows(new_rows))
  }

  list(state = state, changelog = dplyr::bind_rows(changelog))
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
    "naeringskode1_kode"                    = "nace_1",
    "naeringskode1_beskrivelse"             = "nace_1_desc",
    "naeringskode2_kode"                    = "nace_2",
    "naeringskode2_beskrivelse"             = "nace_2_desc",
    "naeringskode3_kode"                    = "nace_3",
    "naeringskode3_beskrivelse"             = "nace_3_desc",
    "forretningsadresse_kommunenummer"      = "municipality_code",
    "forretningsadresse_kommune"            = "municipality",
    "forretningsadresse_postnummer"         = "postal_code",
    "forretningsadresse_poststed"           = "postal_place",
    "forretningsadresse_landkode"           = "country_code",
    "forretningsadresse_land"               = "country",
    "forretningsadresse_adresse_0"          = "street_address",
    "beliggenhetsadresse_kommunenummer"     = "municipality_code",
    "beliggenhetsadresse_kommune"           = "municipality",
    "beliggenhetsadresse_postnummer"        = "postal_code",
    "beliggenhetsadresse_poststed"          = "postal_place",
    "organisasjonsform_kode"                = "legal_form",
    "organisasjonsform_beskrivelse"         = "legal_form_desc",
    "institusjonellSektorkode_kode"         = "sector_code",
    "institusjonellSektorkode_beskrivelse"  = "sector_desc",
    "antallAnsatte"                         = "employees",
    "harRegistrertAntallAnsatte"            = "has_registered_employees",
    "registreringsdatoAntallAnsatteEnhetsregisteret" = "employee_reg_date",
    "registreringsdatoAntallAnsatteNAVAaregisteret"  = "employee_nav_date",
    "konkurs"                               = "bankrupt",
    "konkursdato"                           = "bankruptcy_date",
    "underAvvikling"                        = "in_liquidation",
    "underAvviklingDato"                    = "liquidation_date",
    "underTvangsavviklingEllerTvangsopplosning" = "forced_dissolution",
    "navn"                                  = "name",
    "stiftelsesdato"                        = "founding_date",
    "vedtektsdato"                          = "charter_date",
    "sisteInnsendteAarsregnskap"            = "last_annual_accounts",
    "erIKonsern"                            = "is_group",
    "maalform"                              = "language_form",
    "overordnetEnhet"                       = "parent_org_nr",
    "epostadresse"                          = "email",
    "hjemmeside"                            = "website",
    "telefon"                               = "phone",
    "mobil"                                 = "mobile",
    "slettedato"                            = "deletion_date",
    "datoEierskifte"                        = "ownership_change_date"
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

  empty_paategninger()
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
