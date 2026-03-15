#' Detect changes between two snapshots
#'
#' Compare two dated snapshots and return a tibble of entity-level
#' events: entries (new entities), exits (deleted entities), and
#' field-level changes. Unlike the CDC stream, snapshot diffs provide
#' both old and new values for every changed field.
#'
#' @param date_from,date_to Dates identifying the two snapshots to
#'   compare. Both must exist in the snapshot store. `date_from` is
#'   the "before" state, `date_to` is the "after" state.
#' @param cols Character vector of columns to track for changes.
#'   `NULL` (default) tracks all columns in [field_dict].
#' @param type One of `"enheter"` or `"underenheter"`.
#'
#' @returns A tibble with columns: `org_nr`, `event_type`
#'   (`"entry"`, `"exit"`, `"change"`), `event_date` (the `date_to`
#'   snapshot date), `field` (column name, `NA` for entry/exit),
#'   `value_from` (character, previous value), `value_to` (character,
#'   new value).
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_updates()] for the CDC stream (API-level changes),
#'   [brreg_panel()] for full panel construction.
#'
#' @export
#' @examplesIf interactive() && requireNamespace("arrow", quietly = TRUE)
#' \donttest{
#' snaps <- brreg_snapshots()
#' if (nrow(snaps) >= 2) {
#'   events <- brreg_events(snaps$snapshot_date[1], snaps$snapshot_date[2])
#'   events
#' }
#' }
brreg_events <- function(date_from, date_to,
                          cols = NULL,
                          type = c("enheter", "underenheter")) {
  type <- match.arg(type)
  date_from <- as.Date(date_from)
  date_to <- as.Date(date_to)

  snaps <- brreg_snapshots(type)
  if (!date_from %in% snaps$snapshot_date) {
    cli::cli_abort("No snapshot for {.val {date_from}}. Run {.code brreg_snapshots()} to see available dates.")
  }
  if (!date_to %in% snaps$snapshot_date) {
    cli::cli_abort("No snapshot for {.val {date_to}}. Run {.code brreg_snapshots()} to see available dates.")
  }

  path_from <- snaps$path[snaps$snapshot_date == date_from]
  path_to <- snaps$path[snaps$snapshot_date == date_to]

  old <- read_parquet_safe(path_from)
  new <- read_parquet_safe(path_to)

  track_cols <- if (!is.null(cols)) cols else field_dict$col_name
  track_cols <- intersect(track_cols, intersect(names(old), names(new)))
  track_cols <- setdiff(track_cols, "org_nr")

  old_ids <- old$org_nr
  new_ids <- new$org_nr

  entered <- setdiff(new_ids, old_ids)
  exited <- setdiff(old_ids, new_ids)

  entries <- if (length(entered) > 0) {
    tibble::tibble(
      org_nr = entered,
      event_type = "entry",
      event_date = date_to,
      field = NA_character_,
      value_from = NA_character_,
      value_to = NA_character_
    )
  }

  exits <- if (length(exited) > 0) {
    tibble::tibble(
      org_nr = exited,
      event_type = "exit",
      event_date = date_to,
      field = NA_character_,
      value_from = NA_character_,
      value_to = NA_character_
    )
  }

  common_ids <- intersect(old_ids, new_ids)
  changes <- NULL
  if (length(common_ids) > 0 && length(track_cols) > 0) {
    old_common <- old[old$org_nr %in% common_ids, c("org_nr", track_cols), drop = FALSE]
    new_common <- new[new$org_nr %in% common_ids, c("org_nr", track_cols), drop = FALSE]

    old_common <- old_common[order(old_common$org_nr), ]
    new_common <- new_common[order(new_common$org_nr), ]

    change_list <- vector("list", length(track_cols))
    for (j in seq_along(track_cols)) {
      col <- track_cols[j]
      v_old <- as.character(old_common[[col]])
      v_new <- as.character(new_common[[col]])
      changed <- which(!is.na(v_old) & !is.na(v_new) & v_old != v_new |
                        is.na(v_old) & !is.na(v_new) |
                        !is.na(v_old) & is.na(v_new))
      if (length(changed) > 0) {
        change_list[[j]] <- tibble::tibble(
          org_nr = old_common$org_nr[changed],
          event_type = "change",
          event_date = date_to,
          field = col,
          value_from = v_old[changed],
          value_to = v_new[changed]
        )
      }
    }
    changes <- dplyr::bind_rows(change_list)
  }

  result <- dplyr::bind_rows(entries, exits, changes)
  if (is.null(result) || nrow(result) == 0) {
    result <- tibble::tibble(
      org_nr = character(), event_type = character(),
      event_date = as.Date(character()), field = character(),
      value_from = character(), value_to = character()
    )
  }
  result
}
