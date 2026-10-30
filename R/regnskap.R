#' Retrieve annual accounts (regnskap) from Regnskapsregisteret
#'
#' Fetch the key figures of the annual accounts filed by a Norwegian
#' legal entity from the Regnskapsregisteret open API
#' (`https://data.brreg.no/regnskapsregisteret/regnskap/{orgnr}`). One
#' row per filing is returned. Since 2026-10-01 the default response
#' carries up to three fiscal years per account type, consolidated
#' (`KONSERN`) accounts before company (`SELSKAP`) accounts; requesting
#' an explicit `year` or `account_type` reveals no further years, and
#' years the API no longer serves answer 404.
#'
#' Nested figures are flattened to dot paths and renamed through the
#' package's regnskap field map (`regnskap_dict`, mirrored under
#' `fields` in `inst/extdata/endpoints.json`): balance-sheet and
#' income-statement totals become English columns such as
#' `total_assets`, `total_equity`, `operating_revenue` and
#' `net_income`, all in full units of `currency`. As with
#' [brreg_entity()], only observed fields are emitted and an API field
#' the map does not know passes through under an auto-generated
#' snake_case name, so additions BRREG makes to the filing shape (the
#' asset, tax and cost leaves added 2026-10-01, for instance) are never
#' dropped. An absent leaf is `NA`, not zero.
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
#'   `account_type`, `period_start` and `period_end` (Date), `currency`.
#'   Frequently present: `legal_form`, `parent_company`,
#'   `liquidation_accounts`, `presentation_plan`, `not_audited`,
#'   `audit_waived`, `small_enterprise`, `accounting_rules`,
#'   `total_equity_liabilities`, `total_equity`, `paid_in_equity`,
#'   `retained_equity`, `total_liabilities`, `current_liabilities`,
#'   `long_term_liabilities`, `total_assets`, `current_assets`,
#'   `fixed_assets`, `cash_and_bank`, `receivables`, `investments`,
#'   `inventory`, `goodwill`, `net_income`, `pre_tax_income`,
#'   `comprehensive_income`, `tax_expense`, `extraordinary_items`,
#'   `extraordinary_tax`, `operating_income`, `operating_revenue`,
#'   `sales_revenue`, `operating_expenses`, `payroll_expenses`,
#'   `net_financial_items`, `financial_income`, `financial_expenses`,
#'   `other_interest_expenses`, `intra_group_interest_expenses`. A
#'   zero-row tibble typed on the first seven columns when no filing
#'   is available.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_entity()] for `last_annual_accounts`, the year of
#'   the latest filing the register knows of, [brreg_konsern()] for
#'   the group whose `KONSERN` accounts consolidate an entity,
#'   [tidybrreg_conditions] for the conditions signalled.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_regnskap("923609016")                          # Equinor ASA, all years
#' brreg_regnskap("923609016", account_type = "SELSKAP")
#' brreg_regnskap("923609016", year = 2025)
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

#' Append the `\u00e5r` query parameter with its UTF-8 percent-encoding
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
    period_end = as.Date(character()), currency = character()
  )
}

#' Field map of the Regnskapsregisteret filing shape
#'
#' Dot paths of the filing JSON (OpenAPI 1.1.16) to tidybrreg column
#' names and types, applied by [rename_from_dict()] and
#' [coerce_types()] exactly as [field_dict] is for entities. Source
#' spellings such as `regnkapsprinsipper` and `sumInnskuttEgenkaptial`
#' are the API's own. The same map is published under `fields` in
#' `inst/extdata/endpoints.json` and the two are held equal by
#' `tests/testthat/test-endpoints.R`.
#' @keywords internal
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

#' Flatten a Regnskapsregisteret response to one row per filing
#'
#' Each filing is flattened with [flatten_json()], renamed through
#' [regnskap_dict] by [rename_from_dict()] (observed fields only,
#' unmapped leaves as snake_case) and coerced by [coerce_types()] with
#' the shared reported-failure rule, then the filings are bound and the
#' per-filing parse problems are re-indexed by filing and attached once
#' as `brreg_parse_problems` with one `tidybrreg_warning_parse`. The
#' queried `org_nr` fills the column only when the filing carries no
#' `virksomhet.organisasjonsnummer`.
#'
#' @param raw Parsed JSON list (array of filings).
#' @param org_nr Organization number that was queried.
#' @keywords internal
flatten_regnskap <- function(raw, org_nr) {
  if (length(raw) == 0) return(empty_regnskap())
  problems <- list()
  rows <- lapply(seq_along(raw), function(i) {
    tbl <- rename_from_dict(flatten_json(raw[[i]]), regnskap_dict)
    if (!"org_nr" %in% names(tbl)) tbl$org_nr <- org_nr
    tbl <- withCallingHandlers(
      coerce_types(tbl, regnskap_dict),
      tidybrreg_warning_parse = function(w) invokeRestart("muffleWarning")
    )
    p <- attr(tbl, "brreg_parse_problems")
    if (!is.null(p)) {
      p$row <- i
      problems[[length(problems) + 1L]] <<- p
    }
    attr(tbl, "brreg_parse_problems") <- NULL
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
