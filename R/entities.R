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
#' @section Observed fields only:
#' The register emits only the fields that apply to an entity: a sole
#' proprietorship (`ENK`) typically carries no `founding_date` or
#' `employees`, a foreign branch (`NUF`) no `municipality_code`. The
#' returned columns are exactly the fields the response carried, so
#' every column other than `org_nr`, `registry` and `deleted` is
#' conditionally present. Test for a column with `"x" %in% names(result)`
#' rather than assuming it.
#'
#' @section Tidy shape:
#' Every tibble the package returns is tidy in Wickham's sense: one
#' observation per row, one variable per column, one observational
#' unit per table. The register nests two kinds of array inside an
#' entity. Arrays of strings (`business_address`, `postal_address`,
#' `location_address`, `purpose`, `activity`) are the line fragments
#' of one value and are joined with `"\n"`, which no fragment
#' contains, so `strsplit(x, "\n")` recovers the lines. Arrays of
#' objects (`historiske_navn`, `annotations`, any array of objects the
#' register adds) are observations of another unit and are nested as a
#' list-column of tibbles, one row per element with snake_case
#' columns, `NULL` for an entity without them; `tidyr::unnest()`
#' expands them to their own table. An empty array is not an
#' observation and emits no column. Nothing is serialized to JSON
#' text.
#'
#' @section Deleted entities:
#' BRREG reports a deleted entity either as HTTP 410 or, for most
#' deletions, as HTTP 200 with `respons_klasse = "SlettetEnhet"` and a
#' `slettedato`. Both are modelled the same way: `deleted` is `TRUE`,
#' `deletion_date` is the parsed date, every other field the response
#' carried is kept, and a `tidybrreg_warning_deleted` is signalled
#' (silence it with `suppressWarnings(classes = "tidybrreg_warning_deleted")`).
#' Live entities carry `deleted = FALSE`.
#'
#' @param org_nr Character. A single 9-digit Norwegian organization
#'   number. Validated using [brreg_validate()] before the API call; a
#'   vector of several numbers is an error (iterate with [lapply()]).
#' @param registry One of `"auto"` (default, tries enheter then
#'   underenheter), `"enheter"` (main entities only), or
#'   `"underenheter"` (sub-entities only). Sub-entities have
#'   different fields (e.g. `overordnetEnhet` for the parent
#'   entity, `beliggenhetsadresse` instead of `forretningsadresse`).
#' @param type A type of variables: `"code"` (default) returns raw
#'   codes, `"label"` returns English labels for coded columns
#'   (legal form, NACE, sector, etc.), following the eurostat
#'   package's pattern. Labelling NACE and sector codes consults SSB
#'   KLASS on first use in a session; see [get_brreg_dic()].
#'
#' @returns A tibble with one row and one column per field the API
#'   returned, named via [field_dict], plus `registry` (which registry
#'   answered) and `deleted` (logical). Frequently present columns include
#'   `org_nr`, `name`, `legal_form`, `employees`, `founding_date`,
#'   `nace_1`, `municipality_code`, `bankrupt`, and `parent_org_nr`;
#'   `historiske_navn` and `annotations` are list-columns of tibbles
#'   (see the section on tidy shape).
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_search()] for querying multiple entities,
#'   [brreg_label()] for translating codes to English,
#'   [field_dict] for the column name mapping,
#'   [tidybrreg_conditions] for the errors and warnings signalled.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' # Equinor ASA — Norway's largest company
#' brreg_entity("923609016")
#'
#' # With English labels (eurostat pattern)
#' brreg_entity("923609016", type = "label")
#'
#' # Or pipe to brreg_label() for more control
#' brreg_entity("923609016") |> brreg_label(code = "legal_form")
brreg_entity <- function(org_nr, registry = c("auto", "enheter", "underenheter"),
                          type = c("code", "label")) {
  registry <- match.arg(registry)
  type <- match.arg(type)
  org_nr <- check_org_nr(org_nr)

  registries <- if (registry == "auto") c("enheter", "underenheter") else registry

  resp <- NULL
  matched_registry <- NA_character_
  endpoint <- NA_character_
  for (reg in registries) {
    endpoint <- paste0(reg, "/", org_nr)
    resp <- brreg_perform(brreg_req(endpoint))
    status <- httr2::resp_status(resp)
    if (status %in% c(200L, 410L)) { matched_registry <- reg; break }
    if (status != 404L) break
  }

  status <- httr2::resp_status(resp)
  if (status == 404L) {
    brreg_abort(c(
      "Entity {.val {org_nr}} not found in the Norwegian Business Registry.",
      "i" = "Searched: {.val {registries}}"
    ), class = "not_found", org_nr = org_nr, endpoint = endpoint, status = 404L)
  }
  if (status != 200L && status != 410L) abort_http(resp, endpoint)

  body <- httr2::resp_body_json(resp)
  result <- parse_entity(body)
  if (!"org_nr" %in% names(result)) result$org_nr <- org_nr
  result$registry <- matched_registry
  result <- mark_deleted(result, status, body)
  if (identical(type, "label")) result <- brreg_label(result)
  result
}

#' Flag deletion on an entity row
#'
#' Reads the two signals BRREG uses for a deleted entity (HTTP 410, or
#' `respons_klasse == "SlettetEnhet"` on a 200) and sets `deleted` and
#' `deletion_date` consistently.
#' @keywords internal
mark_deleted <- function(result, status, body) {
  deleted <- status == 410L ||
    identical(body$respons_klasse, "SlettetEnhet") ||
    !is.null(body$slettedato)
  result$deleted <- deleted
  if (deleted) {
    if (!"deletion_date" %in% names(result)) {
      result$deletion_date <- parse_brreg_date(body$slettedato %||% NA_character_)
    }
    brreg_warn(
      "Entity {.val {result$org_nr[1]}} was deleted on {format(result$deletion_date[1])}.",
      class = "deleted", org_nr = result$org_nr[1],
      deletion_date = result$deletion_date[1]
    )
  }
  result
}


#' Search Norwegian legal entities
#'
#' Query the Central Coordinating Register by name, legal form, industry,
#' geography, and other criteria. Results are paginated automatically up to
#' `max_results`.
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
#' @inheritSection brreg_entity Tidy shape
#'
#' @section Result window:
#' The search endpoints allow a page size of up to 10,000 but reject any
#' page where `size * (page + 1)` exceeds 10,000 (observed 2026-08-08:
#' a Bergen municipality query reported 57,954 matches; result 10,001
#' answered HTTP 400 `size * (page+1) kan ikke overstige 10_000`). A query
#' matching more entities than that window cannot be retrieved completely
#' through search. When the register reports more matches than the
#' window and `max_results` asks for more than the window, the call
#' aborts with a `tidybrreg_error_result_window` before any page is
#' returned; narrow the query (for example by `municipality_code`,
#' `legal_form` or `nace_code`), or use [brreg_download()] for the full
#' register. When `max_results` is at or below the window the first
#' `max_results` matches are returned and the result carries
#' `complete = FALSE` plus a `tidybrreg_warning_truncated` whenever
#' more matches exist.
#'
#' @param name Character. Entity name (partial match, case-insensitive).
#' @param legal_form Character. Legal form code: `"AS"`, `"ASA"`, `"ENK"`,
#'   etc. See [legal_forms] for valid codes.
#' @param municipality_code Character. 4-digit Norwegian municipality code.
#' @param nace_code Character. NACE industry code (e.g. `"64.190"`).
#' @param min_employees,max_employees Integer. Employee count range.
#'   For privacy the register refuses a range that lies within one to
#'   four employees (HTTP 400, `tidybrreg_error_http` with the
#'   register's message); ranges starting at 0 or at 5 and above are
#'   served.
#' @param bankrupt Logical. If `TRUE`, return only bankrupt entities.
#'   Only supported for `registry = "enheter"`; supplying it for
#'   `"underenheter"` is an error.
#' @param parent_org_nr Character. Filter to subsidiaries of this org.
#' @param max_results Integer. Maximum entities to return (default 200).
#'   Values above the 10,000 result window are allowed but abort when the
#'   register reports more matches than the window can deliver.
#' @param registry One of `"enheter"` (main entities, default) or
#'   `"underenheter"` (sub-entities / establishments). Sub-entities
#'   use `beliggenhetsadresse.kommunenummer` instead of `kommunenummer`
#'   for geographic filtering, and the `bankrupt` parameter is not
#'   available.
#' @param type A type of variables: `"code"` (default) returns raw
#'   codes, `"label"` returns English labels for coded columns.
#'
#' @returns A tibble with one row per entity. Column names follow the
#'   package field dictionary ([field_dict]); only observed fields are
#'   emitted (see [brreg_entity()]). Attributes: `total_matches`, the
#'   number of matches the register reported, and `complete`, `FALSE`
#'   when fewer rows were returned than matched. A valid empty result is
#'   a zero-row tibble with character columns `org_nr`, `name` and
#'   `legal_form`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_entity()] for single lookups,
#'   [brreg_label()] for translating codes to English,
#'   [tidybrreg_conditions] for the errors and warnings signalled.
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
                          max_results = 200,
                          registry = c("enheter", "underenheter"),
                          type = c("code", "label")) {
  registry <- match.arg(registry)
  type <- match.arg(type)
  max_results <- as.integer(max_results)
  if (length(max_results) != 1L || is.na(max_results) || max_results < 1L) {
    brreg_abort("{.arg max_results} must be a single positive integer.",
                class = "invalid_filter", registry = registry, filter = "max_results")
  }
  if (!is.null(bankrupt) && registry == "underenheter") {
    brreg_abort(c(
      "{.arg bankrupt} is not supported for {.val underenheter}.",
      "i" = "The sub-entity search endpoint has no {.code konkurs} filter; query the parent entity instead."
    ), class = "invalid_filter", registry = registry, filter = "bankrupt")
  }
  retrieval_limit <- 10000L
  filters <- compact(list(
    name = name, legal_form = legal_form, municipality_code = municipality_code,
    nace_code = nace_code, min_employees = min_employees,
    max_employees = max_employees, bankrupt = bankrupt,
    parent_org_nr = parent_org_nr
  ))
  query <- list(
    navn = name,
    organisasjonsform = legal_form,
    naeringskode = nace_code,
    fraAntallAnsatte = min_employees,
    tilAntallAnsatte = max_employees,
    overordnetEnhet = parent_org_nr,
    size = min(100L, max_results),
    page = 0L
  )
  if (registry == "enheter") {
    query$kommunenummer <- municipality_code
    query$konkurs <- if (!is.null(bankrupt)) tolower(as.character(bankrupt))
  } else {
    query$`beliggenhetsadresse.kommunenummer` <- municipality_code
  }

  all_items <- list()
  total <- NULL
  pages <- 0L
  complete <- TRUE
  embed_key <- registry

  repeat {
    resp <- brreg_perform(brreg_req(registry, query = query))
    status <- httr2::resp_status(resp)
    if (status >= 400L) {
      if (pages == 0L) abort_http(resp, registry)
      brreg_warn(c(
        "Search failed with HTTP {status} after {pages} page{?s}; returning the {length(all_items)} entities retrieved so far.",
        "i" = "The result carries {.code attr(x, \"complete\") == FALSE}."
      ), class = "partial", endpoint = registry, status = status, pages_fetched = pages)
      complete <- FALSE
      break
    }
    body <- httr2::resp_body_json(resp)
    pages <- pages + 1L
    if (is.null(total)) {
      total <- as.integer(body$page$totalElements %||% NA_integer_)
      if (!is.na(total) && total > retrieval_limit && max_results > retrieval_limit) {
        brreg_abort(c(
          "The query matches {format(total, big.mark = ',')} entities, more than the {format(retrieval_limit, big.mark = ',')} the search endpoint can return.",
          "i" = "Narrow the query (e.g. by {.arg municipality_code}, {.arg legal_form}, {.arg nace_code}) and combine the partitions, or set {.arg max_results} at or below {format(retrieval_limit, big.mark = ',')} to accept the first matches only.",
          "i" = "For the full register use {.fn brreg_download}."
        ), class = "result_window", endpoint = registry, total_matches = total,
        retrieval_limit = retrieval_limit, filters = filters)
      }
    }
    items <- body[["_embedded"]][[embed_key]]
    if (is.null(items) || length(items) == 0) break
    all_items <- c(all_items, items)
    if (length(all_items) >= max_results) break
    if (is.null(body[["_links"]][["next"]])) break
    query$page <- query$page + 1L
    if ((query$page + 1L) * query$size > retrieval_limit) break
  }

  n <- min(length(all_items), max_results)
  result <- if (n == 0L) empty_entities() else parse_entities(all_items[seq_len(n)])
  total <- total %||% n
  if (!is.na(total) && total > n) {
    complete <- FALSE
    brreg_warn(c(
      "Returned {n} of {format(total, big.mark = ',')} matching entities.",
      "i" = "Raise {.arg max_results} (up to 10,000) or narrow the query; the result carries {.code attr(x, \"complete\") == FALSE}."
    ), class = "truncated", endpoint = registry, returned = n, total_matches = total)
  }
  if (identical(type, "label") && n > 0L) result <- brreg_label(result)
  attr(result, "total_matches") <- total
  attr(result, "complete") <- complete
  result
}


#' Get all sub-units (underenheter) belonging to an entity
#'
#' Convenience wrapper around [brreg_search()] that queries the
#' underenheter registry filtered by `overordnetEnhet`. Each Norwegian
#' legal entity that operates a business has one or more sub-units
#' (BEDR/AAFY) representing physical locations or activities.
#'
#' @param org_nr Character. 9-digit organization number of the
#'   parent entity (hovedenhet).
#' @param max_results Integer. Maximum sub-units to return (default 200).
#'   When the parent has more, the result carries `complete = FALSE`
#'   and a `tidybrreg_warning_truncated` is signalled.
#' @param type One of `"code"` (default) or `"label"`.
#'
#' @returns A tibble with one row per sub-unit. Same column schema and
#'   attributes as [brreg_search()] with `registry = "underenheter"`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_entity()] for the parent entity,
#'   [brreg_children()] for child enheter in the ORGL hierarchy.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_underenheter("923609016")
brreg_underenheter <- function(org_nr, max_results = 200,
                                type = c("code", "label")) {
  org_nr <- check_org_nr(org_nr)
  brreg_search(
    parent_org_nr = org_nr,
    registry      = "underenheter",
    max_results   = max_results,
    type          = type
  )
}


#' Get child entities in the organisational hierarchy
#'
#' Query the enheter registry for entities whose `overordnetEnhet`
#' matches the given org number. This traverses the ORGL parent-child
#' hierarchy (e.g. Stortinget to Riksrevisjonen), which is distinct
#' from the enhet-to-underenhet relationship and from the konsern
#' ownership tree returned by [brreg_konsern()].
#'
#' @inheritParams brreg_underenheter
#'
#' @returns A tibble with one row per child entity. Same column schema
#'   and attributes as [brreg_search()] with `registry = "enheter"`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_underenheter()] for sub-units (BEDR/AAFY),
#'   [brreg_entity()] for single lookups.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_children("971524960")
brreg_children <- function(org_nr, max_results = 200,
                            type = c("code", "label")) {
  org_nr <- check_org_nr(org_nr)
  brreg_search(
    parent_org_nr = org_nr,
    registry      = "enheter",
    max_results   = max_results,
    type          = type
  )
}
