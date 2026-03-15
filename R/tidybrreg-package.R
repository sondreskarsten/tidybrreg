#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||%
#' @importFrom dplyr bind_rows
## usethis namespace: end
NULL

#' Field dictionary: Norwegian API paths to English column names
#'
#' A tibble mapping brreg JSON field paths to English column names and
#' R types. Used internally by the parse engine. API fields absent from
#' this dictionary pass through with auto-generated snake_case names
#' rather than being silently dropped.
#'
#' @format A tibble with 49 rows and 3 columns:
#' \describe{
#'   \item{api_path}{Dot-notation path in the brreg JSON response
#'     (e.g. `"organisasjonsnummer"`, `"forretningsadresse.kommune"`).}
#'   \item{col_name}{English column name used in package output
#'     (e.g. `"org_nr"`, `"municipality"`).}
#'   \item{type}{R type for coercion: `"character"`, `"Date"`,
#'     `"integer"`, or `"logical"`.}
#' }
#'
#' @family tidybrreg reference data
#' @seealso [brreg_entity()] for the function that uses this dictionary.
#'
#' @examples
#' field_dict
#' field_dict[field_dict$type == "Date", ]
"field_dict"

#' Norwegian legal form codes with English translations
#'
#' All organisasjonsformer registered with the Brønnøysund Register
#' Centre, with English translations. Fetched from the brreg API during
#' package build and supplemented with manual English translations.
#'
#' @format A tibble with 44 rows and 4 columns:
#' \describe{
#'   \item{code}{Legal form code (e.g. `"AS"`, `"ASA"`, `"ENK"`).}
#'   \item{name_no}{Norwegian description.}
#'   \item{expired}{Date string if the form is expired, `NA` otherwise.}
#'   \item{name_en}{English translation.}
#' }
#'
#' @family tidybrreg reference data
#' @seealso [brreg_label()] to translate legal form codes in entity data.
#'
#' @examples
#' legal_forms
#' legal_forms[legal_forms$code == "AS", ]
"legal_forms"

#' Role type codes with English translations
#'
#' Maps brreg rolle codes to English names. Used by [brreg_roles()] for
#' automatic role labelling and by [brreg_label()] for post-hoc
#' translation.
#'
#' @format A tibble with 18 rows and 3 columns:
#' \describe{
#'   \item{code}{Role code (e.g. `"LEDE"`, `"MEDL"`, `"DAGL"`).}
#'   \item{name_en}{English translation (e.g. `"Chair of the Board"`).}
#'   \item{name_no}{Norwegian description.}
#' }
#'
#' @family tidybrreg reference data
#' @seealso [brreg_roles()], [role_groups].
#'
#' @examples
#' role_types
"role_types"

#' Role group codes with English translations
#'
#' Maps brreg rollegruppe codes to English names.
#'
#' @format A tibble with 15 rows and 3 columns:
#' \describe{
#'   \item{code}{Role group code (e.g. `"STYR"`, `"DAGL"`, `"REVI"`).}
#'   \item{name_en}{English translation (e.g. `"Board of Directors"`).}
#'   \item{name_no}{Norwegian description.}
#' }
#'
#' @family tidybrreg reference data
#' @seealso [brreg_roles()], [role_types].
#'
#' @examples
#' role_groups
"role_groups"
