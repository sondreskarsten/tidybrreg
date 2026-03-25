#' Query the change log for field-level mutations
#'
#' Returns a filtered view of all recorded changes across the four
#' sync streams: enheter, underenheter, roller, and påtegninger.
#' Every call to [brreg_sync()] appends events to the changelog;
#' this function reads and filters them.
#'
#' @param track Character vector of fields to include (e.g.
#'   `c("nace_1", "municipality_code", "employees")`). `NULL`
#'   returns all fields.
#' @param registry Character vector of streams to include.
#'   Default includes all four.
#' @param change_type Character vector of event types to include.
#'   Options: `"entry"`, `"exit"`, `"change"`,
#'   `"annotation_added"`, `"annotation_cleared"`.
#' @param from,to Date range (inclusive).
#' @param org_nr Optional character vector of organisation numbers.
#'
#' @returns A tibble with columns: `timestamp`, `org_nr`,
#'   `registry`, `change_type`, `field`, `value_from`,
#'   `value_to`, `update_id`.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_sync()] to populate the changelog,
#'   [brreg_flows()] for aggregated entry/exit counts.
#'
#' @export
#' @examplesIf interactive()
#' \donttest{
#' brreg_sync()
#'
#' # All changes this month
#' brreg_changes(from = Sys.Date() - 30)
#'
#' # NACE reclassifications only
#' brreg_changes(track = "nace_1", change_type = "change")
#'
#' # Entries and exits for a specific entity
#' brreg_changes(org_nr = "923609016", change_type = c("entry", "exit"))
#'
#' # All annotation events
#' brreg_changes(registry = "paategninger")
#' }
brreg_changes <- function(track = NULL,
                           registry = NULL,
                           change_type = NULL,
                           from = NULL,
                           to = NULL,
                           org_nr = NULL) {
  log <- read_changelog(
    from = from,
    to = to,
    registry = registry,
    change_type = change_type
  )

  if (nrow(log) == 0) return(log)

  if (!is.null(track)) {
    log <- log[is.na(log$field) | log$field %in% track, ]
  }

  if (!is.null(org_nr)) {
    log <- log[log$org_nr %in% org_nr, ]
  }

  log[order(log$timestamp), ]
}


#' Summarize changes by field and type
#'
#' Produces a count table of how many changes occurred per field
#' and change type, useful for understanding the volume and
#' distribution of registry mutations.
#'
#' @inheritParams brreg_changes
#'
#' @returns A tibble with `registry`, `change_type`, `field`, `n`.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_changes()] for raw changelog rows,
#'   [brreg_sync()] to populate the changelog.
#' @export
#' @examplesIf interactive()
#' brreg_change_summary(from = Sys.Date() - 7)
brreg_change_summary <- function(from = NULL, to = NULL, registry = NULL) {
  log <- read_changelog(from = from, to = to, registry = registry)
  if (nrow(log) == 0) {
    return(tibble::tibble(
      registry = character(), change_type = character(),
      field = character(), n = integer()
    ))
  }

  log |>
    dplyr::summarise(
      n = dplyr::n(),
      .by = c("registry", "change_type", "field")
    ) |>
    dplyr::arrange(.data$registry, dplyr::desc(.data$n))
}
