#' Retrieve historical names (historiskeNavn) for entities
#'
#' Norwegian entities keep their organization number across renames;
#' the register exposes prior names with the interval each was in
#' force. BRREG added the `historiskeNavn` field to enheter and
#' underenheter on 2026-06-16. Name history accrues through
#' [brreg_sync()]: every rename in the CDC feed appends the superseded
#' name here. History predating your first sync exists only in the
#' JSON bulk download and is backfilled when bootstrapping with
#' `brreg_sync(format = "json")`.
#'
#' Requires [brreg_sync()] to have been run at least once to populate
#' the local name-history state.
#'
#' @param org_nr Optional character vector of organisation numbers.
#'   `NULL` returns all name history.
#'
#' @returns A tibble with columns: `org_nr`, `position` (array
#'   index), `name` (the superseded name), `from_date`, `to_date`
#'   (register timestamps as observed, format
#'   `"YYYY-MM-DD HH:MM:SS"`, kept as character).
#'
#' @family tidybrreg data management functions
#' @seealso [brreg_sync()] to populate name-history data,
#'   [brreg_changes()] with `registry = "historiske_navn"` to track
#'   rename events over time.
#'
#' @export
#' @examplesIf interactive()
#' \donttest{
#' brreg_sync()
#' brreg_historical_names()
#' brreg_historical_names("923609016")
#' }
brreg_historical_names <- function(org_nr = NULL) {
  state <- read_state("historiske_navn")
  if (is.null(state) || nrow(state) == 0) {
    cli::cli_alert_warning(
      "No name-history data. Run {.code brreg_sync()} first."
    )
    return(empty_historiske_navn())
  }

  result <- state
  if (!is.null(org_nr)) {
    result <- result[result$org_nr %in% org_nr, ]
  }
  result
}
