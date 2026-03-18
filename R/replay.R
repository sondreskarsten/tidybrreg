#' Reconstruct register state by replaying CDC updates
#'
#' Given a base snapshot and a stream of CDC updates from
#' [brreg_updates()], reconstruct the state of the register at any
#' arbitrary date. Uses `dplyr::rows_upsert()` for Ny/Endring events
#' and `dplyr::rows_delete()` for Sletting events, applied
#' chronologically.
#'
#' @param base A tibble from [brreg_download()], [brreg_import()], or
#'   a snapshot read via [brreg_open()]. Must contain `org_nr`.
#' @param updates A tibble from [brreg_updates()] with
#'   `include_changes = TRUE`. Must contain `org_nr`, `change_type`,
#'   `timestamp`, and `changes` (list-column of patch tibbles).
#' @param target_date Date. Reconstruct state as of this date.
#'   Only updates with `timestamp <= target_date` are applied.
#' @param cols Character vector of columns to track. If `NULL`,
#'   all columns present in `base` are used.
#'
#' @returns A tibble with the same columns as `base`, reflecting
#'   all applied changes up to `target_date`. Attribute
#'   `replay_info` records the number of inserts, updates, and
#'   deletes applied.
#'
#' @section Limitations:
#' The brreg CDC stream provides only new values (not old values)
#' in RFC 6902 JSON Patch format, and field-level changes are only
#' available from September 2025. Before that date, only the
#' change type (Ny/Endring/Sletting) is recorded — field-level
#' replay is not possible for those periods. Use [brreg_events()]
#' (snapshot diff) for pre-September 2025 field-level changes.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_panel()] for multi-snapshot panels,
#'   [brreg_updates()] to fetch the CDC stream.
#'
#' @export
#' @examplesIf FALSE
#' base <- brreg_download(type_output = "tibble")
#' updates <- brreg_updates(since = Sys.Date() - 30,
#'                           size = 10000, include_changes = TRUE)
#' state <- brreg_replay(base, updates, target_date = Sys.Date())
brreg_replay <- function(base, updates, target_date = Sys.Date(),
                          cols = NULL) {
  target_date <- as.POSIXct(as.Date(target_date))
  updates <- updates[updates$timestamp <= target_date, , drop = FALSE]
  if (nrow(updates) == 0) return(base)

  updates <- updates[order(updates$timestamp), ]

  state <- base
  if (!is.null(cols)) {
    keep <- unique(c("org_nr", cols))
    keep <- intersect(keep, names(state))
    state <- state[, keep, drop = FALSE]
  }

  n_insert <- 0L
  n_update <- 0L
  n_delete <- 0L

  for (i in seq_len(nrow(updates))) {
    u <- updates[i, ]
    org <- u$org_nr
    ct <- u$change_type

    if (ct == "Sletting" || ct == "Fjernet") {
      if (org %in% state$org_nr) {
        state <- state[state$org_nr != org, , drop = FALSE]
        n_delete <- n_delete + 1L
      }
      next
    }

    if (ct == "Ny" && !org %in% state$org_nr) {
      new_row <- tibble::tibble(org_nr = org)
      if ("changes" %in% names(u) && !is.null(u$changes[[1]])) {
        new_row <- apply_patch_to_row(new_row, u$changes[[1]], names(state))
      }
      for (col in setdiff(names(state), names(new_row))) {
        new_row[[col]] <- NA
      }
      state <- dplyr::bind_rows(state, new_row[, names(state), drop = FALSE])
      n_insert <- n_insert + 1L
      next
    }

    if (ct == "Endring" && org %in% state$org_nr) {
      if ("changes" %in% names(u) && !is.null(u$changes[[1]])) {
        idx <- which(state$org_nr == org)[1]
        patch <- u$changes[[1]]
        for (j in seq_len(nrow(patch))) {
          field <- patch$field[j]
          col <- lookup_patch_field(field, names(state))
          if (!is.null(col) && col %in% names(state)) {
            new_val <- patch$new_value[j]
            if (is.integer(state[[col]])) {
              state[[col]][idx] <- suppressWarnings(as.integer(new_val))
            } else if (is.logical(state[[col]])) {
              state[[col]][idx] <- as.logical(new_val)
            } else if (inherits(state[[col]], "Date")) {
              state[[col]][idx] <- as.Date(new_val)
            } else if (is.numeric(state[[col]])) {
              state[[col]][idx] <- suppressWarnings(as.numeric(new_val))
            } else {
              state[[col]][idx] <- new_val
            }
          }
        }
      }
      n_update <- n_update + 1L
    }
  }

  attr(state, "replay_info") <- list(
    target_date = as.Date(target_date),
    n_updates_applied = nrow(updates),
    n_insert = n_insert,
    n_update = n_update,
    n_delete = n_delete
  )
  state
}


#' Apply a patch tibble to a new row
#' @keywords internal
apply_patch_to_row <- function(row, patch, valid_cols) {
  for (j in seq_len(nrow(patch))) {
    col <- lookup_patch_field(patch$field[j], valid_cols)
    if (!is.null(col)) row[[col]] <- patch$new_value[j]
  }
  row
}


#' Map a CDC patch field path to a column name
#'
#' Patch fields use camelCase slash-separated paths
#' (e.g. `forretningsadresse/postnummer`). This maps them to
#' the field_dict col_name or auto snake_case.
#'
#' @keywords internal
lookup_patch_field <- function(field, valid_cols) {
  api_path <- gsub("_", ".", field)
  dict_map <- stats::setNames(field_dict$col_name, tolower(field_dict$api_path))
  lcn <- tolower(api_path)
  if (lcn %in% names(dict_map)) return(dict_map[[lcn]])
  snake <- to_snake(field)
  if (snake %in% valid_cols) return(snake)
  NULL
}
