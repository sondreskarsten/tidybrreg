#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||% .data .env
#' @importFrom dplyr bind_rows
## usethis namespace: end
NULL

#' Session-level cache for the managed store
#' @keywords internal
.brregEnv <- new.env(parent = emptyenv())

utils::globalVariables(c("annotation_infotypes"))
#' Annotation infotype codes with English descriptions
#'
#' Maps brreg påtegning `infotype` codes to English descriptions. Used by
#' [brreg_annotations()] when `translate = TRUE`. Covers the infotype
#' codes documented in the brreg API reference (`"NAVN"`, `"FADR"`) and
#' those observed in live data (role codes used for missing-role
#' annotations); unknown codes pass through unchanged. Each annotation's
#' own Norwegian text is available in the `tekst` column of
#' [brreg_annotations()] output.
#'
#' @format A tibble with 7 rows and 2 columns:
#' \describe{
#'   \item{code}{Annotation infotype code (e.g. `"FADR"`, `"NAVN"`).}
#'   \item{name_en}{English description.}
#' }
#'
#' @family tidybrregpanel reference data
#' @seealso [brreg_annotations()] for the function that uses this table.
#'
#' @examples
#' annotation_infotypes
"annotation_infotypes"
