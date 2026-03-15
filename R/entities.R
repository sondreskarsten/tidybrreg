#' Look up a Norwegian legal entity
#'
#' Retrieve registration details for a legal entity from Norway's Central
#' Coordinating Register for Legal Entities (Enhetsregisteret), maintained
#' by the Brønnøysund Register Centre. Every legal entity operating in
#' Norway is assigned a unique 9-digit organization number and registered
#' in this central register.
#'
#' Column names are translated from Norwegian to English via the package
#' field dictionary ([field_dict]). API fields not in the dictionary pass
#' through with auto-generated snake_case names, so new fields added by
#' brreg are never silently dropped. Use [brreg_label()] to translate
#' coded values (legal forms, NACE codes) to English descriptions.
#'
#' @param org_nr Character. A 9-digit Norwegian organization number.
#'   Validated using [brreg_validate()] before the API call.
#'
#' @returns A tibble with one row and one column per API field. Column
#'   names follow the package field dictionary. Key columns include
#'   `org_nr`, `name`, `legal_form`, `employees`, `founding_date`,
#'   `nace_1`, `municipality_code`, `bankrupt`, and `parent_org_nr`.
#'   For deleted entities (HTTP 410), returns a tibble with columns
#'   `org_nr`, `deleted`, and `deletion_date`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_search()] for querying multiple entities,
#'   [brreg_label()] for translating codes to English,
#'   [field_dict] for the column name mapping.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' # Equinor ASA — Norway's largest company
#' brreg_entity("923609016")
#'
#' # With English labels
#' brreg_entity("923609016") |> brreg_label()
brreg_entity <- function(org_nr) {
  org_nr <- as.character(org_nr)
  if (!brreg_validate(org_nr)) {
    cli::cli_abort(c(
      "Invalid organization number: {.val {org_nr}}",
      "i" = "Must be 9 digits starting with 8 or 9, with a modulus-11 check digit.",
      "i" = "Examples: 923609016 (Equinor), 984851006 (DNB Bank)"
    ))
  }
  resp <- brreg_req(paste0("enheter/", org_nr)) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  status <- httr2::resp_status(resp)
  if (status == 410L) {
    body <- httr2::resp_body_json(resp)
    cli::cli_warn("Entity {.val {org_nr}} was deleted on {body$slettedato}.")
    return(tibble::tibble(
      org_nr = org_nr, deleted = TRUE,
      deletion_date = as.Date(body$slettedato)
    ))
  }
  if (status == 404L) {
    cli::cli_abort("Entity {.val {org_nr}} not found in the Norwegian Business Registry.")
  }
  if (status >= 400L) {
    cli::cli_abort("Norwegian Business Registry API error: HTTP {status}")
  }
  parse_entity(httr2::resp_body_json(resp))
}


#' Search Norwegian legal entities
#'
#' Query the Central Coordinating Register by name, legal form, industry,
#' geography, and other criteria. Results are paginated automatically up to
#' `max_results` or the API's 10,000-result ceiling, whichever is lower.
#'
#' @section Norwegian legal forms:
#' Common codes for the `legal_form` parameter:
#' - **AS**: Private limited company (like UK Ltd, German GmbH)
#' - **ASA**: Public limited company (like UK PLC, German AG)
#' - **ENK**: Sole proprietorship
#' - **NUF**: Norwegian-registered foreign entity (branch office)
#'
#' See [legal_forms] for the complete list with English translations.
#'
#' @param name Character. Entity name (partial match, case-insensitive).
#' @param legal_form Character. Legal form code: `"AS"`, `"ASA"`, `"ENK"`,
#'   etc. See [legal_forms] for valid codes.
#' @param municipality_code Character. 4-digit Norwegian municipality code.
#' @param nace_code Character. NACE industry code (e.g. `"64.190"`).
#' @param min_employees,max_employees Integer. Employee count range.
#' @param bankrupt Logical. If `TRUE`, return only bankrupt entities.
#' @param parent_org_nr Character. Filter to subsidiaries of this org.
#' @param max_results Integer. Maximum entities to return (default 200).
#'   The API caps search results at 10,000; use `brreg_download()` for
#'   larger extractions.
#'
#' @returns A tibble with one row per entity. Column names follow the
#'   package field dictionary ([field_dict]). An attribute `total_matches`
#'   records the total number of matches in the registry.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_entity()] for single lookups,
#'   [brreg_label()] for translating codes to English.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' # Search by name
#' brreg_search(name = "Equinor")
#'
#' # Large private companies in Oslo
#' brreg_search(legal_form = "AS", municipality_code = "0301",
#'              min_employees = 500, max_results = 10)
brreg_search <- function(name = NULL, legal_form = NULL,
                          municipality_code = NULL, nace_code = NULL,
                          min_employees = NULL, max_employees = NULL,
                          bankrupt = NULL, parent_org_nr = NULL,
                          max_results = 200) {
  query <- list(
    navn = name,
    organisasjonsform = legal_form,
    kommunenummer = municipality_code,
    naeringskode = nace_code,
    fraAntallAnsatte = min_employees,
    tilAntallAnsatte = max_employees,
    konkurs = if (!is.null(bankrupt)) tolower(as.character(bankrupt)),
    overordnetEnhet = parent_org_nr,
    size = min(100L, max_results),
    page = 0
  )

  all_items <- list()
  total <- NULL

  repeat {
    resp <- brreg_req("enheter") |>
      httr2::req_url_query(!!!compact(query)) |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) >= 400L) break
    body <- httr2::resp_body_json(resp)
    if (is.null(total)) total <- body$page$totalElements
    items <- body[["_embedded"]][["enheter"]]
    if (is.null(items) || length(items) == 0) break
    all_items <- c(all_items, items)
    if (length(all_items) >= max_results) break
    if (is.null(body[["_links"]][["next"]])) break
    query$page <- query$page + 1L
    if ((query$page + 1L) * query$size > 10000L) {
      cli::cli_warn("Reached the 10,000-result API limit.")
      break
    }
  }
  if (length(all_items) == 0) return(tibble::tibble())
  n <- min(length(all_items), max_results)
  result <- parse_entities(all_items[seq_len(n)])
  attr(result, "total_matches") <- total
  result
}
