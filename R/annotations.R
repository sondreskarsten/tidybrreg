#' Retrieve registry annotations (påtegninger) for entities
#'
#' Påtegninger are public annotations placed on entities by the
#' register keeper to warn third parties of irregularities — missing
#' board members, undelivered accounts, deceased officers. They are
#' the earliest formal signal that an entity is in regulatory
#' trouble, preceding forced dissolution warnings by weeks to months.
#'
#' Requires [brreg_sync()] to have been run at least once to
#' populate the local påtegninger state.
#'
#' @param org_nr Optional character vector of organisation numbers.
#'   `NULL` returns all annotations.
#' @param infotype Optional character vector of annotation type codes
#'   to filter by (e.g. `"FADR"`, `"NAVN"`).
#' @param active_only Logical. If `TRUE` (default), return only
#'   annotations currently in force. If `FALSE`, include cleared
#'   annotations from the changelog.
#'
#' @returns A tibble with columns: `org_nr`, `position` (array
#'   index), `infotype`, `tekst` (annotation text),
#'   `innfoert_dato` (date introduced).
#'
#' @family tidybrreg data management functions
#' @seealso [brreg_sync()] to populate annotation data,
#'   [brreg_changes()] to track annotation events over time.
#'
#' @export
#' @examplesIf interactive()
#' \donttest{
#' brreg_sync()
#' brreg_annotations()
#' brreg_annotations(infotype = "FADR")
#' }
brreg_annotations <- function(org_nr = NULL, infotype = NULL,
                               active_only = TRUE) {
  state <- read_state("paategninger")
  if (is.null(state) || nrow(state) == 0) {
    cli::cli_alert_warning("No annotation data. Run {.code brreg_sync()} first.")
    return(empty_paategninger())
  }

  result <- state
  if (!is.null(org_nr)) {
    result <- result[result$org_nr %in% org_nr, ]
  }
  if (!is.null(infotype)) {
    result <- result[result$infotype %in% infotype, ]
  }
  result
}


#' Count entities with active annotations
#'
#' Quick summary of how many entities currently carry påtegninger,
#' grouped by annotation type.
#'
#' @returns A tibble with `infotype` and `n`.
#'
#' @family tidybrreg data management functions
#' @export
#' @examplesIf interactive()
#' brreg_annotation_summary()
brreg_annotation_summary <- function() {
  state <- read_state("paategninger")
  if (is.null(state) || nrow(state) == 0) {
    cli::cli_alert_warning("No annotation data. Run {.code brreg_sync()} first.")
    return(tibble::tibble(infotype = character(), n_entities = integer(), n_annotations = integer()))
  }
  state |>
    dplyr::summarise(
      n_entities = dplyr::n_distinct(.data$org_nr),
      n_annotations = dplyr::n(),
      .by = "infotype"
    ) |>
    dplyr::arrange(dplyr::desc(.data$n_annotations))
}
