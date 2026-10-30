#' Retrieve annual accounts (regnskap) from Regnskapsregisteret
#'
#' Fetch the key figures of the annual accounts filed by a Norwegian
#' legal entity from the Regnskapsregisteret open API
#' (`https://data.brreg.no/regnskapsregisteret/regnskap/{orgnr}`,
#' OpenAPI 1.1.16). One row per filing is returned. Since 2026-10-01 the
#' default response carries up to three fiscal years per account type,
#' consolidated (`KONSERN`) accounts before company (`SELSKAP`) accounts;
#' requesting an explicit `year` or `account_type` reveals no further
#' years, and years the API no longer serves answer 404.
#'
#' @section Shape:
#' The result is nested in the tidyr sense: the filing is the
#' observational unit of the outer table and its line items are the
#' observational unit of the `items` table nested in each row. Filing
#' attributes (identity, period, currency, legal form, audit and
#' accounting-principle flags) are scalar columns renamed through the
#' package's regnskap field map (`regnskap_dict`, published as `fields`
#' in `inst/extdata/endpoints.json`). The figures of the three statement
#' objects the API emits (`eiendeler`, `egenkapitalGjeld`,
#' `resultatregnskapResultat`) are rows of `items`, one per leaf, with:
#'
#' - `statement`: `assets`, `equity_liabilities` or `income_statement`.
#' - `group`: English name of the object the leaf sits in
#'   (`current_assets`, `equity`, `operating_revenue`, ...), from the
#'   group map (`groups` in the endpoint spec).
#' - `item`: English name of the leaf (`total_assets`, `cash_and_bank`,
#'   `net_income`, ...), from the field map.
#' - `path`: the API's dot path, unchanged.
#' - `level`: depth of the leaf in the API's structure.
#' - `is_sum`: whether the API names the leaf `sum...`, its own marking
#'   of a total.
#' - `value`: the amount in full units of `currency`.
#'
#' The API's grouping is structural, not an additive partition: a
#' group's total sits beside components and beside sub-group totals
#' (`sumEiendeler` next to `sumOmloepsmidler` and `sumFordringer`), so
#' adding `value` across items double counts unless `is_sum` and
#' `group` are used. `tidyr::unnest(items)` gives the long form and
#' `tidyr::pivot_wider(names_from = item, values_from = value)` the
#' wide form. As with [brreg_entity()], only observed fields are
#' emitted and an API field the maps do not know passes through under
#' an auto-generated snake_case name (an unknown leaf inside a statement
#' becomes an item, an unknown object outside the statements becomes
#' scalar columns), so additions BRREG makes to the filing shape are
#' never dropped. An absent leaf is absent, not zero; an object the API
#' sends empty (`{}`) contributes no items.
#'
#' @section Consistency flags:
#' Filings are published as filed; the register does not correct them
#' and neither does this function, but it checks the accounting
#' identities the structure implies (balance sheet balances, equity and
#' liabilities add up to their totals, operating and financial results
#' and net income follow from their components; the list is
#' `identities` in the endpoint spec) and flags what fails.
#' `consistent` is `TRUE` when every checkable identity holds within a
#' tolerance of 1 unit of currency, `FALSE` when any fails and `NA`
#' when none is checkable (an identity is checkable when its total and
#' every non-optional term are present). `inconsistencies` names the
#' failing identities, newline-separated, and is `NA` when none fails.
#' In the October 2026 population (1,129,601 filings) between 0.1% and
#' 2.5% of filings fail each identity at that tolerance.
#'
#' The logical account key is `org_nr`, `account_type` and the year of
#' `period_end`; `filing_id` identifies the filing itself (a new id
#' under the same key is a resubmission) and `journal_nr` can be shared
#' by the `SELSKAP` and `KONSERN` filings of one submission.
#'
#' @section Unsupported accounting plans:
#' Banks, insurers, pension funds and other entities whose accounting
#' plan (`BANK`, `SKADE`, `LIV`, `PENSJ`, `IDEELL`, ...) the API does
#' not serve answer HTTP 500 with the message
#' `oppstillingsplan som ikke er støttet (PLAN)`. That is a property of
#' the entity, not a transient failure: the typed zero-row tibble is
#' returned with attributes `http_status = 500L` and `unsupported_plan`
#' (the plan code), and a `tidybrreg_warning_unsupported_plan` is
#' signalled. Any other HTTP 500 aborts as documented below.
#'
#' @inheritSection brreg_roles Status handling
#'
#' @param org_nr Character. A single 9-digit organization number,
#'   validated with [brreg_validate()].
#' @param year Integer. A single calendar year of the fiscal period's
#'   end date (`period_end`), including non-calendar fiscal years.
#'   `NULL` (default) returns every year the API serves.
#' @param account_type Character. `"SELSKAP"` (the company's own
#'   accounts) or `"KONSERN"` (the group accounts). `NULL` (default)
#'   returns both.
#'
#' @returns A tibble with one row per filing. Always present when a
#'   filing is returned: `org_nr`, `filing_id` (integer), `journal_nr`,
#'   `account_type`, `period_start` and `period_end` (Date), `currency`,
#'   `items` (list of tibbles with columns `statement`, `group`, `item`,
#'   `path`, `level`, `is_sum`, `value`), `consistent` (logical) and
#'   `inconsistencies` (character). Frequently present: `legal_form`,
#'   `parent_company`, `liquidation_accounts`, `presentation_plan`,
#'   `not_audited`, `audit_waived`, `small_enterprise`,
#'   `accounting_rules`. A zero-row tibble typed on the always-present
#'   columns when no filing is available.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_entity()] for `last_annual_accounts`, the year of
#'   the latest filing the register knows of, [brreg_konsern()] for
#'   the group whose `KONSERN` accounts consolidate an entity,
#'   [tidybrreg_conditions] for the conditions signalled.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' acc <- brreg_regnskap("923609016")                   # Equinor ASA, all years
#' acc[c("account_type", "period_end", "consistent")]
#' tidyr::unnest(acc, items)                             # one row per line item
#' brreg_regnskap("923609016", account_type = "SELSKAP", year = 2025)
brreg_regnskap <- function(org_nr, year = NULL, account_type = NULL) {
  org_nr <- check_org_nr(org_nr)
  if (!is.null(account_type)) {
    account_type <- match.arg(account_type, c("SELSKAP", "KONSERN"))
  }
  endpoint <- org_nr
  req <- brreg_req(endpoint, list(regnskapstype = account_type),
                   service = "regnskapsregisteret")
  if (!is.null(year)) req <- add_year_query(req, year)
  resp <- brreg_perform(req)
  out <- regnskap_unsupported(resp, org_nr, empty_regnskap())
  if (!is.null(out)) return(out)
  out <- satellite_status(resp, endpoint, org_nr, empty_regnskap())
  if (!is.null(out)) return(out)
  flatten_regnskap(httr2::resp_body_json(resp), org_nr)
}

#' Append the `år` query parameter with its UTF-8 percent-encoding
#'
#' The parameter name is non-ASCII. [httr2::req_url_query()] escapes
#' names in the session's native encoding, which in a non-UTF-8 session
#' renders the name as `<c3><a5>r` rather than `%C3%A5r`, so the name
#' is appended pre-encoded and the same bytes are sent in every locale.
#' @keywords internal
add_year_query <- function(req, year) {
  sep <- if (grepl("?", req$url, fixed = TRUE)) "&" else "?"
  httr2::req_url(req, paste0(req$url, sep, "%C3%A5r=", as.integer(year)))
}

#' Typed zero-row tibble for regnskap results
#' @keywords internal
empty_regnskap <- function() {
  tibble::tibble(
    org_nr = character(), filing_id = integer(), journal_nr = character(),
    account_type = character(), period_start = as.Date(character()),
    period_end = as.Date(character()), currency = character(),
    items = list(), consistent = logical(), inconsistencies = character()
  )
}

#' Typed zero-row line-item table
#' @keywords internal
empty_items <- function() {
  tibble::tibble(
    statement = character(), group = character(), item = character(),
    path = character(), level = integer(), is_sum = logical(),
    value = numeric()
  )
}

#' Maps of the Regnskapsregisteret filing shape
#'
#' `regnskap_dict` maps dot paths of the filing JSON (OpenAPI 1.1.16)
#' to tidybrreg names and types, applied by [rename_from_dict()] and
#' [coerce_types()] exactly as [field_dict] is for entities, and names
#' the line items. `regnskap_groups` names the objects that group line
#' items and `regnskap_statements` the three statement objects.
#' `regnskap_identities` lists the accounting identities checked per
#' filing on the line items (by item name; `optional` terms count as 0
#' when absent) within `regnskap_tolerance`. Source spellings such as
#' `regnkapsprinsipper` and `sumInnskuttEgenkaptial` are the API's own.
#' All of this is published under `brreg_regnskap` in
#' `inst/extdata/endpoints.json` and held equal to these objects by
#' `tests/testthat/test-endpoints.R`.
#' @name regnskap_maps
#' @keywords internal
NULL

regnskap_dict <- tibble::tribble(
  ~api_path, ~col_name, ~type,
  "id", "filing_id", "integer",
  "journalnr", "journal_nr", "character",
  "regnskapstype", "account_type", "character",
  "virksomhet.organisasjonsnummer", "org_nr", "character",
  "virksomhet.organisasjonsform", "legal_form", "character",
  "virksomhet.morselskap", "parent_company", "logical",
  "regnskapsperiode.fraDato", "period_start", "Date",
  "regnskapsperiode.tilDato", "period_end", "Date",
  "valuta", "currency", "character",
  "avviklingsregnskap", "liquidation_accounts", "logical",
  "oppstillingsplan", "presentation_plan", "character",
  "revisjon.ikkeRevidertAarsregnskap", "not_audited", "logical",
  "revisjon.fravalgRevisjon", "audit_waived", "logical",
  "regnkapsprinsipper.smaaForetak", "small_enterprise", "logical",
  "regnkapsprinsipper.regnskapsregler", "accounting_rules", "character",
  "egenkapitalGjeld.sumEgenkapitalGjeld", "total_equity_liabilities", "numeric",
  "egenkapitalGjeld.egenkapital.sumEgenkapital", "total_equity", "numeric",
  "egenkapitalGjeld.egenkapital.innskuttEgenkapital.sumInnskuttEgenkaptial", "paid_in_equity", "numeric",
  "egenkapitalGjeld.egenkapital.opptjentEgenkapital.sumOpptjentEgenkapital", "retained_equity", "numeric",
  "egenkapitalGjeld.gjeldOversikt.sumGjeld", "total_liabilities", "numeric",
  "egenkapitalGjeld.gjeldOversikt.kortsiktigGjeld.sumKortsiktigGjeld", "current_liabilities", "numeric",
  "egenkapitalGjeld.gjeldOversikt.langsiktigGjeld.sumLangsiktigGjeld", "long_term_liabilities", "numeric",
  "eiendeler.sumEiendeler", "total_assets", "numeric",
  "eiendeler.omloepsmidler.sumOmloepsmidler", "current_assets", "numeric",
  "eiendeler.anleggsmidler.sumAnleggsmidler", "fixed_assets", "numeric",
  "eiendeler.sumBankinnskuddOgKontanter", "cash_and_bank", "numeric",
  "eiendeler.sumFordringer", "receivables", "numeric",
  "eiendeler.sumInvesteringer", "investments", "numeric",
  "eiendeler.sumVarer", "inventory", "numeric",
  "eiendeler.goodwill", "goodwill", "numeric",
  "resultatregnskapResultat.aarsresultat", "net_income", "numeric",
  "resultatregnskapResultat.ordinaertResultatFoerSkattekostnad", "pre_tax_income", "numeric",
  "resultatregnskapResultat.totalresultat", "comprehensive_income", "numeric",
  "resultatregnskapResultat.ordinaertResultatSkattekostnad", "tax_expense", "numeric",
  "resultatregnskapResultat.ekstraordinaerePoster", "extraordinary_items", "numeric",
  "resultatregnskapResultat.skattekostnadEkstraordinaertResultat", "extraordinary_tax", "numeric",
  "resultatregnskapResultat.driftsresultat.driftsresultat", "operating_income", "numeric",
  "resultatregnskapResultat.driftsresultat.driftsinntekter.sumDriftsinntekter", "operating_revenue", "numeric",
  "resultatregnskapResultat.driftsresultat.driftsinntekter.salgsinntekter", "sales_revenue", "numeric",
  "resultatregnskapResultat.driftsresultat.driftskostnad.sumDriftskostnad", "operating_expenses", "numeric",
  "resultatregnskapResultat.driftsresultat.driftskostnad.loennskostnad", "payroll_expenses", "numeric",
  "resultatregnskapResultat.finansresultat.nettoFinans", "net_financial_items", "numeric",
  "resultatregnskapResultat.finansresultat.finansinntekt.sumFinansinntekter", "financial_income", "numeric",
  "resultatregnskapResultat.finansresultat.finanskostnad.sumFinanskostnad", "financial_expenses", "numeric",
  "resultatregnskapResultat.finansresultat.finanskostnad.annenRentekostnad", "other_interest_expenses", "numeric",
  "resultatregnskapResultat.finansresultat.finanskostnad.rentekostnadSammeKonsern", "intra_group_interest_expenses", "numeric"
)

regnskap_groups <- tibble::tribble(
  ~path, ~group,
  "eiendeler", "assets",
  "eiendeler.omloepsmidler", "current_assets",
  "eiendeler.anleggsmidler", "fixed_assets",
  "egenkapitalGjeld", "equity_liabilities",
  "egenkapitalGjeld.egenkapital", "equity",
  "egenkapitalGjeld.egenkapital.innskuttEgenkapital", "paid_in_equity",
  "egenkapitalGjeld.egenkapital.opptjentEgenkapital", "retained_equity",
  "egenkapitalGjeld.gjeldOversikt", "liabilities",
  "egenkapitalGjeld.gjeldOversikt.kortsiktigGjeld", "current_liabilities",
  "egenkapitalGjeld.gjeldOversikt.langsiktigGjeld", "long_term_liabilities",
  "resultatregnskapResultat", "income_statement",
  "resultatregnskapResultat.driftsresultat", "operating",
  "resultatregnskapResultat.driftsresultat.driftsinntekter", "operating_revenue",
  "resultatregnskapResultat.driftsresultat.driftskostnad", "operating_expenses",
  "resultatregnskapResultat.finansresultat", "financial",
  "resultatregnskapResultat.finansresultat.finansinntekt", "financial_income",
  "resultatregnskapResultat.finansresultat.finanskostnad", "financial_expenses"
)

regnskap_statements <- c("eiendeler" = "assets", "egenkapitalGjeld" = "equity_liabilities", "resultatregnskapResultat" = "income_statement")

regnskap_identities <- list(
  list(name = "balance", lhs = "total_equity_liabilities", plus = c("total_assets"), minus = character(), optional = character()),
  list(name = "equity_liabilities", lhs = "total_equity_liabilities", plus = c("total_equity", "total_liabilities"), minus = character(), optional = character()),
  list(name = "equity", lhs = "total_equity", plus = c("paid_in_equity", "retained_equity"), minus = character(), optional = character()),
  list(name = "liabilities", lhs = "total_liabilities", plus = c("current_liabilities", "long_term_liabilities"), minus = character(), optional = character()),
  list(name = "assets", lhs = "total_assets", plus = c("current_assets", "fixed_assets"), minus = character(), optional = character()),
  list(name = "operating", lhs = "operating_income", plus = c("operating_revenue"), minus = c("operating_expenses"), optional = character()),
  list(name = "financial", lhs = "net_financial_items", plus = c("financial_income"), minus = c("financial_expenses"), optional = character()),
  list(name = "pre_tax", lhs = "pre_tax_income", plus = c("operating_income", "net_financial_items"), minus = character(), optional = character()),
  list(name = "net_income", lhs = "net_income", plus = c("pre_tax_income", "extraordinary_items"), minus = c("tax_expense", "extraordinary_tax"), optional = c("extraordinary_items", "extraordinary_tax"))
)
regnskap_tolerance <- 1

#' Statement each dot path belongs to
#' @returns Character vector: the statement name, or `NA` for a path
#'   outside the statement objects.
#' @keywords internal
statement_of <- function(path) {
  unname(regnskap_statements[sub("\\..*$", "", path)])
}

#' Build the line-item table of one filing
#'
#' @param flat Named list of the filing's statement leaves (dot paths).
#' @returns A list with `items` (tibble), `failed` (indices of values
#'   that did not parse as numbers) and `actual` (their raw text).
#' @keywords internal
build_items <- function(flat) {
  if (length(flat) == 0) return(list(items = empty_items(), failed = integer(), actual = character()))
  path <- names(flat)
  parts <- strsplit(path, ".", fixed = TRUE)
  leaf <- vapply(parts, function(p) p[length(p)], character(1))
  node <- vapply(parts, function(p) paste(p[-length(p)], collapse = "."), character(1))
  group <- regnskap_groups$group[match(node, regnskap_groups$path)]
  unknown <- is.na(group)
  group[unknown] <- vapply(parts[unknown], function(p) {
    if (length(p) < 2L) unname(regnskap_statements[p[1]]) else to_snake(p[length(p) - 1L])
  }, character(1))
  item <- regnskap_dict$col_name[match(path, regnskap_dict$api_path)]
  item[is.na(item)] <- to_snake(leaf[is.na(item)])
  present <- !vapply(flat, function(v) is.null(v) || length(v) == 0 || (length(v) == 1L && is.na(v[[1]])), logical(1))
  numeric_in <- vapply(flat, function(v) length(v) == 1L && is.numeric(v[[1]]), logical(1))
  value <- rep(NA_real_, length(flat))
  value[numeric_in] <- vapply(flat[numeric_in], function(v) as.numeric(v[[1]]), numeric(1))
  other <- present & !numeric_in
  actual <- rep(NA_character_, length(flat))
  actual[other] <- vapply(flat[other], function(v) as.character(v[[1]]), character(1))
  value[other] <- suppressWarnings(as.numeric(actual[other]))
  items <- tibble::tibble(
    statement = statement_of(path),
    group = group,
    item = item,
    path = path,
    level = lengths(parts) - 1L,
    is_sum = startsWith(leaf, "sum"),
    value = value
  )
  list(items = items, failed = which(present & is.na(value)), actual = actual)
}

#' Check the accounting identities of one filing
#' @param items The filing's line-item table from [build_items()].
#' @returns A list with `consistent` (logical, `NA` when nothing is
#'   checkable) and `inconsistencies` (newline-separated names, `NA`
#'   when none fails).
#' @keywords internal
check_identities <- function(items) {
  value_of <- function(name) {
    i <- match(name, items$item)
    if (is.na(i)) NA_real_ else items$value[i]
  }
  checked <- character()
  failed <- character()
  for (rule in regnskap_identities) {
    lhs <- value_of(rule$lhs)
    terms <- c(rule$plus, rule$minus)
    vals <- vapply(terms, value_of, numeric(1))
    required <- setdiff(terms, rule$optional)
    if (is.na(lhs) || anyNA(vals[required])) next
    vals[is.na(vals)] <- 0
    rhs <- sum(vals[rule$plus]) - sum(vals[rule$minus])
    checked <- c(checked, rule$name)
    if (abs(lhs - rhs) > regnskap_tolerance) failed <- c(failed, rule$name)
  }
  list(
    consistent = if (length(checked) == 0) NA else length(failed) == 0,
    inconsistencies = if (length(failed) == 0) NA_character_ else paste(failed, collapse = "\n")
  )
}

#' Map the unsupported-accounting-plan response to a typed empty result
#'
#' Regnskapsregisteret answers HTTP 500 with the message
#' `oppstillingsplan som ikke er støttet (PLAN)` (also seen spelled
#' `stottet`) for entities whose accounting plan it does not serve.
#' @returns `NULL` unless the response is that case, otherwise the typed
#'   empty with attributes `http_status`, `unsupported_plan` and a
#'   `tidybrreg_warning_unsupported_plan`.
#' @keywords internal
regnskap_unsupported <- function(resp, org_nr, empty, call = rlang::caller_env()) {
  if (httr2::resp_status(resp) != 500L) return(NULL)
  body <- tryCatch(httr2::resp_body_json(resp), error = \(e) list())
  message <- body$message %||% ""
  if (!grepl("oppstillingsplan som ikke er st", message, fixed = TRUE)) return(NULL)
  plan <- regmatches(message, regexpr("\\(([A-Z]+)\\)", message))
  plan <- if (length(plan) == 1L) gsub("[()]", "", plan) else NA_character_
  brreg_warn(
    "Entity {.val {org_nr}} files accounts under a plan the API does not serve ({.val {plan}}).",
    class = "unsupported_plan", org_nr = org_nr, plan = plan, api_message = message,
    call = call
  )
  attr(empty, "http_status") <- 500L
  attr(empty, "unsupported_plan") <- plan
  empty
}

#' Flatten a Regnskapsregisteret response to one nested row per filing
#'
#' Each filing is flattened with [flatten_json()]. Leaves inside the
#' statement objects become the filing's `items` table
#' ([build_items()]); the other leaves are renamed through
#' `regnskap_dict` ([regnskap_maps]) by [rename_from_dict()] (observed fields only,
#' unmapped leaves as snake_case) and coerced by [coerce_types()] with
#' the shared reported-failure rule. The identities are checked
#' ([check_identities()]), the filings are bound, and the per-filing
#' parse problems (scalar columns and `items.value`) are re-indexed by
#' filing and attached once as `brreg_parse_problems` with one
#' `tidybrreg_warning_parse`. The queried `org_nr` fills the column
#' only when the filing carries no `virksomhet.organisasjonsnummer`.
#'
#' @param raw Parsed JSON list (array of filings).
#' @param org_nr Organization number that was queried.
#' @keywords internal
flatten_regnskap <- function(raw, org_nr) {
  if (length(raw) == 0) return(empty_regnskap())
  problems <- list()
  rows <- lapply(seq_along(raw), function(i) {
    flat <- flatten_json(raw[[i]])
    flat <- flat[!is_hal_link_path(names(flat))]
    in_statement <- !is.na(statement_of(names(flat)))
    built <- build_items(flat[in_statement])
    tbl <- rename_from_dict(flat[!in_statement], regnskap_dict)
    if (!"org_nr" %in% names(tbl)) tbl$org_nr <- org_nr
    tbl <- withCallingHandlers(
      coerce_types(tbl, regnskap_dict),
      tidybrreg_warning_parse = function(w) invokeRestart("muffleWarning")
    )
    p <- attr(tbl, "brreg_parse_problems")
    attr(tbl, "brreg_parse_problems") <- NULL
    if (length(built$failed) > 0) {
      p <- dplyr::bind_rows(p, parse_problem_rows("items.value", "numeric", built$actual, built$failed))
    }
    if (!is.null(p) && nrow(p) > 0) {
      p$row <- i
      problems[[length(problems) + 1L]] <<- p
    }
    flags <- check_identities(built$items)
    tbl$items <- list(built$items)
    tbl$consistent <- flags$consistent
    tbl$inconsistencies <- flags$inconsistencies
    tbl
  })
  out <- dplyr::relocate(dplyr::bind_rows(rows), "org_nr")
  if (length(problems) == 0) return(out)
  all_problems <- dplyr::bind_rows(problems)
  by_column <- lapply(split(all_problems, all_problems$column), function(p) {
    p$n_failed <- nrow(p)
    p[seq_len(min(nrow(p), 20L)), ]
  })
  attach_parse_problems(out, by_column)
}
