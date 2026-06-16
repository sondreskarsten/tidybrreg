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
#' [role_types] alongside the board roles.
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
#' @param org_nr Character. 9-digit organization number.
#'
#' @returns A tibble with one row per person per signing combination.
#'   Columns: `org_nr`, `entity_name`, `signature_type` (`"signature"`),
#'   `rule_status`, `rule_text`, `combination_id`, `combination_code`,
#'   `rule`, `name`, `birth_date`, `role_code`, `role`. Returns an empty
#'   tibble if the entity has no registered signing combination.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_prokura()] for procuration, [brreg_roles()] for the
#'   underlying role assignments.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_signatur("923609016") # Equinor ASA
brreg_signatur <- function(org_nr) {
  org_nr <- as.character(org_nr)
  resp <- brreg_req(paste0("enheter/", org_nr, "/signatur"),
                    service = "fullmakt") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) {
    cli::cli_warn("No signatur found for {.val {org_nr}} (HTTP {httr2::resp_status(resp)}).")
    return(tibble::tibble())
  }
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
#'
#' @param org_nr Character. 9-digit organization number.
#'
#' @returns A tibble with the same columns as [brreg_signatur()], with
#'   `signature_type` set to `"procuration"`. Returns an empty tibble if
#'   no procuration is registered.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_signatur()] for general signing authority.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_prokura("923609016") # Equinor ASA
brreg_prokura <- function(org_nr) {
  org_nr <- as.character(org_nr)
  resp <- brreg_req(paste0("enheter/", org_nr, "/prokura"),
                    service = "fullmakt") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) {
    cli::cli_warn("No prokura found for {.val {org_nr}} (HTTP {httr2::resp_status(resp)}).")
    return(tibble::tibble())
  }
  flatten_signatur(httr2::resp_body_json(resp), org_nr, "procuration")
}


#' Flatten a Fullmakt signature/procuration response to a tibble
#' @param raw Parsed JSON list from a signatur or prokura endpoint.
#' @param org_nr Organization number (passed through to output).
#' @param signature_type `"signatur"` or `"prokura"`.
#' @keywords internal
flatten_signatur <- function(raw, org_nr, signature_type) {
  komb <- raw$signeringsKombinasjon$kombinasjon
  if (is.null(komb) || length(komb) == 0) return(tibble::tibble())
  entity_name <- raw$enhet$navn %||% NA_character_
  rule_status <- raw$status$regelStatus$kode %||% NA_character_
  rule_text   <- raw$signeringsGrunnlag$signaturProkuraRoller$signaturProkuraFritekst %||% NA_character_
  rows <- vector("list", 200)
  k <- 0L
  for (kb in komb) {
    rule    <- kb$tekstforklaring %||% NA_character_
    kid     <- kb$kombinasjonsId %||% NA_character_
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
  if (k == 0L) return(tibble::tibble())
  result <- dplyr::bind_rows(lapply(rows[seq_len(k)], tibble::as_tibble))
  result$birth_date <- as.Date(result$birth_date, format = "%d.%m.%Y")
  result
}
