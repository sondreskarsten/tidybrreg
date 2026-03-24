#' Retrieve board members, officers, and auditors
#'
#' Fetch all registered roles for a Norwegian legal entity. Returns one
#' row per role assignment. Person-held roles include name and birth date.
#' Entity-held roles (auditor firms, accountants) include the entity's
#' organization number.
#'
#' Role types and groups are returned as English labels looked up from
#' the package's [role_types] and [role_groups] reference datasets.
#' Original Norwegian codes are preserved in `role_code` and
#' `role_group_code`.
#'
#' @section Person identification:
#' The `person_id` column is a synthetic key composed of birth date, last
#' name, first name, and middle name. It enables network analysis across
#' companies but has a non-trivial collision risk for common Norwegian
#' names sharing a birth date. The brreg public API does not expose
#' national identity numbers.
#'
#' @param org_nr Character. 9-digit organization number.
#'
#' @returns A tibble with one row per role assignment. Columns:
#'   `org_nr`, `role_group`, `role_group_code`, `role`, `role_code`,
#'   `first_name`, `middle_name`, `last_name`, `birth_date`, `deceased`,
#'   `entity_org_nr`, `entity_name`, `resigned`, `deregistered`,
#'   `ordering`, `elected_by`, `group_modified`, `person_id`.
#'   Returns an empty tibble if the entity has no registered roles.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_board_summary()] for derived board covariates,
#'   [role_types] and [role_groups] for the English lookup tables.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_roles("923609016")  # Equinor ASA
brreg_roles <- function(org_nr) {
  org_nr <- as.character(org_nr)
  resp <- brreg_req(paste0("enheter/", org_nr, "/roller")) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) {
    cli::cli_warn("No roles found for {.val {org_nr}} (HTTP {httr2::resp_status(resp)}).")
    return(tibble::tibble())
  }
  flatten_roles(httr2::resp_body_json(resp), org_nr)
}


#' Flatten nested rollegrupper/roller JSON to a tibble
#' @param raw Parsed JSON list from the roles endpoint.
#' @param org_nr Organization number (passed through to output).
#' @keywords internal
flatten_roles <- function(raw, org_nr) {
  grupper <- raw$rollegrupper
  if (is.null(grupper) || length(grupper) == 0) return(tibble::tibble())
  rows <- vector("list", 200)
  k <- 0L
  for (g in grupper) {
    if (is.null(g$roller)) next
    g_code <- g$type$kode %||% NA_character_
    g_modified <- g$sistEndret %||% NA_character_
    for (r in g$roller) {
      k <- k + 1L
      rows[[k]] <- list(
        org_nr          = org_nr,
        role_group_code = g_code,
        role_group      = lookup_role_group(g_code),
        role_code       = r$type$kode %||% NA_character_,
        role            = lookup_role(r$type$kode),
        first_name      = r$person$navn$fornavn %||% NA_character_,
        middle_name     = r$person$navn$mellomnavn %||% NA_character_,
        last_name       = r$person$navn$etternavn %||% NA_character_,
        birth_date      = r$person$fodselsdato %||% NA_character_,
        deceased        = r$person$erDoed %||% NA,
        entity_org_nr   = r$enhet$organisasjonsnummer %||% NA_character_,
        entity_name     = extract_entity_name(r$enhet$navn),
        resigned        = r$fratraadt %||% FALSE,
        deregistered    = r$avregistrert %||% NA,
        ordering        = r$rekkefolge %||% NA_integer_,
        elected_by      = r$valgtAv$kode %||% NA_character_,
        group_modified  = g_modified
      )
    }
  }
  if (k == 0L) return(tibble::tibble())
  result <- dplyr::bind_rows(lapply(rows[seq_len(k)], tibble::as_tibble))
  result$birth_date <- as.Date(result$birth_date)
  result$group_modified <- as.Date(result$group_modified)
  result$person_id <- ifelse(
    !is.na(result$birth_date) & !is.na(result$last_name),
    paste(result$birth_date, tolower(result$last_name),
          tolower(result$first_name),
          tolower(ifelse(is.na(result$middle_name), "", result$middle_name)),
          sep = "_"),
    NA_character_
  )
  result
}


#' Extract entity name from role JSON (parser-agnostic)
#'
#' jsonlite returns `navn` as a named list (`$navnelinje1`).
#' yyjsonr collapses single-element objects to bare character.
#' This handles both.
#'
#' @param navn The `enhet$navn` element from parsed role JSON.
#' @returns Character scalar.
#' @keywords internal
extract_entity_name <- function(navn) {
  if (is.null(navn)) return(NA_character_)
  if (is.character(navn)) return(paste(navn, collapse = " "))
  if (is.list(navn) && is.null(names(navn))) {
    return(paste(unlist(navn), collapse = " "))
  }
  navn$navnelinje1 %||% NA_character_
}


#' @keywords internal
lookup_role <- function(code) {
  if (is.null(code) || is.na(code)) return(NA_character_)
  idx <- match(enc2utf8(code), enc2utf8(role_types$code))
  if (is.na(idx)) return(code)
  role_types$name_en[idx]
}

#' @keywords internal
lookup_role_group <- function(code) {
  if (is.null(code) || is.na(code)) return(NA_character_)
  idx <- match(enc2utf8(code), enc2utf8(role_groups$code))
  if (is.na(idx)) return(code)
  role_groups$name_en[idx]
}


#' Vectorised role code to English label
#' @param codes Character vector of role type codes.
#' @returns Character vector of English labels. Unknown codes pass through.
#' @keywords internal
lookup_role_vec <- function(codes) {
  idx <- match(codes, role_types$code)
  out <- role_types$name_en[idx]
  fallback <- is.na(idx) & !is.na(codes)
  out[fallback] <- codes[fallback]
  out
}


#' Vectorised role group code to English label
#' @param codes Character vector of role group codes.
#' @returns Character vector of English labels. Unknown codes pass through.
#' @keywords internal
lookup_role_group_vec <- function(codes) {
  idx <- match(codes, role_groups$code)
  out <- role_groups$name_en[idx]
  fallback <- is.na(idx) & !is.na(codes)
  out[fallback] <- codes[fallback]
  out
}


#' Derive board-level summary covariates from role data
#'
#' Compute firm-level variables commonly used in corporate governance
#' research: board size, composition counts, and officer indicators.
#'
#' @param roles A tibble returned by [brreg_roles()].
#'
#' @returns A 1-row tibble with columns: `org_nr`, `board_size`,
#'   `n_chair`, `n_deputy_chair`, `n_members`, `n_alternates`,
#'   `n_observers`, `n_employee_elected`, `has_ceo`, `has_auditor`,
#'   `auditor_org_nr`. Counts exclude resigned and deregistered roles.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_roles()] for the underlying role data.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_roles("923609016") |> brreg_board_summary()
brreg_board_summary <- function(roles) {
  active_filter <- !isTRUE(roles$resigned) & !isTRUE(roles$deregistered)
  if ("resigned" %in% names(roles)) {
    active_filter <- !(roles$resigned %in% TRUE) & !(roles$deregistered %in% TRUE)
  }
  board <- roles[roles$role_group_code == "STYR" & !is.na(roles$person_id) & active_filter, ]
  tibble::tibble(
    org_nr         = roles$org_nr[1],
    board_size     = nrow(board),
    n_chair        = sum(board$role_code == "LEDE", na.rm = TRUE),
    n_deputy_chair = sum(board$role_code == "NEST", na.rm = TRUE),
    n_members      = sum(board$role_code == "MEDL", na.rm = TRUE),
    n_alternates   = sum(board$role_code == "VARA", na.rm = TRUE),
    n_observers    = sum(board$role_code == "OBS", na.rm = TRUE),
    n_employee_elected = sum(!is.na(board$elected_by), na.rm = TRUE),
    has_ceo        = any(roles$role_group_code == "DAGL" & active_filter, na.rm = TRUE),
    has_auditor    = any(roles$role_group_code == "REVI" & active_filter, na.rm = TRUE),
    auditor_org_nr = {
      revi <- roles[roles$role_group_code == "REVI" & !is.na(roles$entity_org_nr) & active_filter, ]
      if (nrow(revi) > 0) revi$entity_org_nr[1] else NA_character_
    }
  )
}


#' Retrieve roles an entity holds in other entities
#'
#' Reverse role lookup: find all entities where the given entity holds
#' a role (e.g. parent company, shareholder, general partner). This
#' is distinct from [brreg_roles()], which returns who holds roles
#' IN the given entity.
#'
#' @param org_nr Character. 9-digit organization number.
#'
#' @returns A tibble with one row per role held. Columns: `org_nr`
#'   (queried entity), `target_org_nr` (entity where role is held),
#'   `target_name`, `role_code`, `role`, `share` (ownership share
#'   if applicable), `resigned`, `deregistered`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_roles()] for who holds roles in an entity.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_roles_legal("923609016")  # Equinor's roles in other entities
brreg_roles_legal <- function(org_nr) {
  org_nr <- as.character(org_nr)
  resp <- brreg_req(paste0("roller/enheter/", org_nr, "/juridiskeroller")) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) return(tibble::tibble())
  body <- httr2::resp_body_json(resp)
  enheter <- body$enheter
  if (is.null(enheter) || length(enheter) == 0) return(tibble::tibble())

  rows <- vector("list", length(enheter) * 3L)
  k <- 0L
  for (e in enheter) {
    for (r in (e$roller %||% list())) {
      k <- k + 1L
      rows[[k]] <- tibble::tibble(
        org_nr          = org_nr,
        target_org_nr   = e$organisasjonsnummer %||% NA_character_,
        target_name     = e$navn %||% NA_character_,
        role_code       = r$type$kode %||% NA_character_,
        role            = lookup_role(r$type$kode),
        share           = r$ansvarsandel %||% NA_character_,
        resigned        = r$fratraadt %||% FALSE,
        deregistered    = r$avregistrert %||% FALSE
      )
    }
  }
  if (k == 0L) return(tibble::tibble())
  dplyr::bind_rows(rows[seq_len(k)])
}
