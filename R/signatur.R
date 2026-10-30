#' Retrieve signature authority (signaturrett)
#'
#' Fetch the registered signing combinations for a Norwegian legal
#' entity from the Brønnøysund Fullmakt service. Signature authority
#' determines who may bind the entity in general, and is distinct from
#' the roles returned by [brreg_roles()]: an entity may have many board
#' members yet a signing rule such as "the board jointly" or "the
#' general manager alone".
#'
#' Each registered combination (`combination_id`) carries a rule
#' (`rule`, e.g. "Styret i fellesskap") and the persons who satisfy it.
#' One row is returned per person within each combination.
#'
#' @section Person identification:
#' The Fullmakt service returns each person's name as a single string in
#' `name`; it does not split it into given and family names, so no
#' synthetic `person_id` is constructed. Join to [brreg_roles()] on
#' `birth_date` together with `name` at query time if cross-referencing
#' to the role network is required. Role designations are returned as
#' English labels looked up from [role_types], with the original
#' Norwegian code preserved in `role_code`; the signing-mode designations
#' (`SIGN`, `SIFE`, `SIHV`, `PROK`, `POFE`, `POHV`) are included in
#' [role_types] alongside the board roles. Birth dates arrive as
#' `DD.MM.YYYY` from this service and as ISO dates from the roles
#' endpoint; both are parsed to `Date`, so the two join directly.
#'
#' @section Standardised vs registered rule:
#' `rule` and `combination_code` come from the registry's structured
#' combination. Where the rule has been standardised (`rule_status` code
#' `"RF"`) this is the registered rule. Where it has not (`"RI"`), the
#' structured combination is the statutory default ("the board jointly")
#' and the actually registered rule is the free text in `rule_text`;
#' read `rule_text` in that case. `rule_text` may be `NA` when no free
#' text is recorded.
#'
#' @inheritSection brreg_roles Status handling
#'
#' @param org_nr Character. A single 9-digit organization number.
#'
#' @returns A tibble with one row per person per signing combination.
#'   Columns: `org_nr`, `entity_name`, `signature_type` (`"signature"`),
#'   `rule_status`, `rule_text`, `combination_id`, `combination_code`,
#'   `rule`, `name`, `birth_date` (Date), `role_code`, `role`. A
#'   zero-row tibble with the same typed columns if the entity has no
#'   registered signing combination.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_prokura()] for procuration, [brreg_roles()] for the
#'   underlying role assignments.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_signatur("923609016") # Equinor ASA
brreg_signatur <- function(org_nr) {
  org_nr <- check_org_nr(org_nr)
  endpoint <- paste0("enheter/", org_nr, "/signatur")
  resp <- brreg_perform(brreg_req(endpoint, service = "fullmakt"))
  out <- satellite_status(resp, endpoint, org_nr, empty_signatur())
  if (!is.null(out)) return(out)
  flatten_signatur(httr2::resp_body_json(resp), org_nr, "signature")
}


#' Retrieve procuration authority (prokura)
#'
#' Fetch the registered procuration combinations for a Norwegian legal
#' entity from the Brønnøysund Fullmakt service. Procuration is a
#' commercial power of attorney under the Norwegian Powers of Attorney
#' Act (prokuraloven): a holder may bind the entity in ordinary
#' business, but not, absent separate authority, sell or encumber its
#' real property. It is a narrower and separate mandate from the general
#' signing authority returned by [brreg_signatur()].
#'
#' One row is returned per person within each registered combination.
#'
#' @inheritSection brreg_signatur Person identification
#' @inheritSection brreg_roles Status handling
#'
#' @param org_nr Character. A single 9-digit organization number.
#'
#' @returns A tibble with the same columns as [brreg_signatur()], with
#'   `signature_type` set to `"procuration"`. A zero-row tibble with the
#'   same typed columns if no procuration is registered.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_signatur()] for general signing authority.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_prokura("923609016") # Equinor ASA
brreg_prokura <- function(org_nr) {
  org_nr <- check_org_nr(org_nr)
  endpoint <- paste0("enheter/", org_nr, "/prokura")
  resp <- brreg_perform(brreg_req(endpoint, service = "fullmakt"))
  out <- satellite_status(resp, endpoint, org_nr, empty_signatur())
  if (!is.null(out)) return(out)
  flatten_signatur(httr2::resp_body_json(resp), org_nr, "procuration")
}

#' Typed zero-row tibble for signature and procuration results
#' @keywords internal
empty_signatur <- function() {
  tibble::tibble(
    org_nr = character(), entity_name = character(),
    signature_type = character(), rule_status = character(),
    rule_text = character(), combination_id = character(),
    combination_code = character(), rule = character(), name = character(),
    birth_date = as.Date(character()), role_code = character(),
    role = character()
  )
}


#' Flatten a Fullmakt signature/procuration response to a tibble
#' @param raw Parsed JSON list from a signatur or prokura endpoint.
#' @param org_nr Organization number (passed through to output).
#' @param signature_type `"signature"` or `"procuration"`.
#' @keywords internal
flatten_signatur <- function(raw, org_nr, signature_type) {
  komb <- raw$signeringsKombinasjon$kombinasjon
  if (is.null(komb) || length(komb) == 0) return(empty_signatur())
  entity_name <- raw$enhet$navn %||% NA_character_
  rule_status <- raw$status$regelStatus$kode %||% NA_character_
  rule_text   <- raw$signeringsGrunnlag$signaturProkuraRoller$signaturProkuraFritekst %||% NA_character_
  rows <- vector("list", 200)
  k <- 0L
  for (kb in komb) {
    rule    <- kb$tekstforklaring %||% NA_character_
    kid     <- as.character(kb$kombinasjonsId %||% NA_character_)
    kcode   <- kb$kode %||% NA_character_
    persons <- kb$personRolleKombinasjon
    if (is.null(persons) || length(persons) == 0) {
      k <- k + 1L
      rows[[k]] <- list(
        org_nr           = org_nr,
        entity_name      = entity_name,
        signature_type   = signature_type,
        rule_status      = rule_status,
        rule_text        = rule_text,
        combination_id   = kid,
        combination_code = kcode,
        rule             = rule,
        name             = NA_character_,
        birth_date       = NA_character_,
        role_code        = NA_character_,
        role             = NA_character_
      )
      next
    }
    for (p in persons) {
      k <- k + 1L
      rows[[k]] <- list(
        org_nr           = org_nr,
        entity_name      = entity_name,
        signature_type   = signature_type,
        rule_status      = rule_status,
        rule_text        = rule_text,
        combination_id   = kid,
        combination_code = kcode,
        rule             = rule,
        name             = p$navn %||% NA_character_,
        birth_date       = p$fodselsdato %||% NA_character_,
        role_code        = p$rolle$kode %||% NA_character_,
        role             = lookup_role(p$rolle$kode)
      )
    }
  }
  if (k == 0L) return(empty_signatur())
  result <- dplyr::bind_rows(lapply(rows[seq_len(k)], tibble::as_tibble))
  result$birth_date <- parse_brreg_date(result$birth_date)
  result
}
