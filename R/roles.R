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
#' @section Status handling:
#' The per-entity endpoints behind [brreg_roles()], [brreg_roles_legal()],
#' [brreg_konsern()], [brreg_signatur()], [brreg_prokura()] and
#' [brreg_regnskap()] share one contract. HTTP 404 means the organization
#' number is unknown to that endpoint, which for konsern, signatur,
#' prokura and regnskap is the ordinary case of an entity with nothing
#' registered there: the typed zero-row tibble
#' is returned with attribute `http_status = 404L` and no warning. HTTP
#' 410 means the entity has been deleted: the typed zero-row tibble is
#' returned with `http_status = 410L`, `deletion_date`, and a
#' `tidybrreg_warning_deleted`. Any other status of 400 or above aborts
#' with a `tidybrreg_error_http`. A successful response with nothing
#' registered returns the typed zero-row tibble with no attribute. Use
#' [brreg_entity()] to distinguish a non-existent organization number
#' from a live entity with nothing registered.
#'
#' @param org_nr Character. A single 9-digit organization number,
#'   validated with [brreg_validate()].
#'
#' @returns A tibble with one row per role assignment. Columns:
#'   `org_nr`, `role_group_code`, `role_group`, `role_code`, `role`,
#'   `first_name`, `middle_name`, `last_name`, `birth_date` (Date),
#'   `deceased`, `entity_org_nr`, `entity_name`, `deregistered`,
#'   `ordering`, `elected_by`, `group_modified` (Date), `person_id`.
#'   A `resigned` column is present only when the payload carries the
#'   `fratraadt` field, which BRREG removed on 2026-06-16; live
#'   responses no longer include the column, while replays of older
#'   data retain it. An entity with no registered roles yields a
#'   zero-row tibble with the same typed columns.
#'
#' @family tidybrreg entity functions
#' @seealso [role_types] and [role_groups] for the English lookup
#'   tables, [tidybrreg_conditions] for the conditions signalled.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_roles("923609016")  # Equinor ASA
brreg_roles <- function(org_nr) {
  org_nr <- check_org_nr(org_nr)
  endpoint <- paste0("enheter/", org_nr, "/roller")
  resp <- brreg_perform(brreg_req(endpoint))
  out <- satellite_status(resp, endpoint, org_nr, empty_roles())
  if (!is.null(out)) return(out)
  flatten_roles(httr2::resp_body_json(resp), org_nr)
}

#' Typed zero-row tibble for role results
#' @keywords internal
empty_roles <- function() {
  tibble::tibble(
    org_nr = character(), role_group_code = character(),
    role_group = character(), role_code = character(), role = character(),
    first_name = character(), middle_name = character(),
    last_name = character(), birth_date = as.Date(character()),
    deceased = logical(), entity_org_nr = character(),
    entity_name = character(), deregistered = logical(),
    ordering = integer(), elected_by = character(),
    group_modified = as.Date(character()), person_id = character()
  )
}


#' Flatten nested rollegrupper/roller JSON to a tibble
#' @param raw Parsed JSON list from the roles endpoint.
#' @param org_nr Organization number (passed through to output).
#' @keywords internal
flatten_roles <- function(raw, org_nr) {
  grupper <- raw$rollegrupper
  if (is.null(grupper) || length(grupper) == 0) return(empty_roles())
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
        resigned        = r$fratraadt %||% NA,
        deregistered    = r$avregistrert %||% NA,
        ordering        = r$rekkefolge %||% NA_integer_,
        elected_by      = r$valgtAv$kode %||% NA_character_,
        group_modified  = g_modified
      )
    }
  }
  if (k == 0L) return(empty_roles())
  result <- dplyr::bind_rows(lapply(rows[seq_len(k)], tibble::as_tibble))
  if (all(is.na(result$resigned))) {
    result$resigned <- NULL
  } else {
    result$resigned[is.na(result$resigned)] <- FALSE
  }
  result$birth_date <- parse_brreg_date(result$birth_date)
  result$group_modified <- parse_brreg_date(result$group_modified)
  result$deceased <- as.logical(result$deceased)
  result$deregistered <- as.logical(result$deregistered)
  result$ordering <- as.integer(result$ordering)
  result$person_id <- make_person_id(result)
  result
}

#' Synthetic person key from birth date and name parts
#' @keywords internal
make_person_id <- function(x) {
  ifelse(
    !is.na(x$birth_date) & !is.na(x$last_name),
    paste(x$birth_date, tolower(x$last_name),
          tolower(x$first_name),
          tolower(ifelse(is.na(x$middle_name), "", x$middle_name)),
          sep = "_"),
    NA_character_
  )
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


#' Retrieve roles an entity holds in other entities
#'
#' Reverse role lookup: find all entities where the given entity holds
#' a role (e.g. parent company, shareholder, general partner). This
#' is distinct from [brreg_roles()], which returns who holds roles
#' IN the given entity.
#'
#' @inheritSection brreg_roles Status handling
#'
#' @param org_nr Character. A single 9-digit organization number.
#'
#' @returns A tibble with one row per role held. Columns: `org_nr`
#'   (queried entity), `target_org_nr` (entity where role is held),
#'   `target_name`, `role_code`, `role`, `share` (ownership share
#'   if applicable), `deregistered`. A `resigned` column is present
#'   only when the payload carries the `fratraadt` field, removed by
#'   BRREG on 2026-06-16. An entity holding no roles elsewhere yields a
#'   zero-row tibble with the same typed columns.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_roles()] for who holds roles in an entity.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_roles_legal("923609016")  # Equinor's roles in other entities
brreg_roles_legal <- function(org_nr) {
  org_nr <- check_org_nr(org_nr)
  endpoint <- paste0("roller/enheter/", org_nr, "/juridiskeroller")
  resp <- brreg_perform(brreg_req(endpoint))
  out <- satellite_status(resp, endpoint, org_nr, empty_roles_legal())
  if (!is.null(out)) return(out)
  body <- httr2::resp_body_json(resp)
  enheter <- body$enheter
  if (is.null(enheter) || length(enheter) == 0) return(empty_roles_legal())

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
        resigned        = r$fratraadt %||% NA,
        deregistered    = r$avregistrert %||% FALSE
      )
    }
  }
  if (k == 0L) return(empty_roles_legal())
  result <- dplyr::bind_rows(rows[seq_len(k)])
  if (all(is.na(result$resigned))) {
    result$resigned <- NULL
  } else {
    result$resigned[is.na(result$resigned)] <- FALSE
  }
  result
}

#' Typed zero-row tibble for legal-role results
#' @keywords internal
empty_roles_legal <- function() {
  tibble::tibble(
    org_nr = character(), target_org_nr = character(),
    target_name = character(), role_code = character(), role = character(),
    share = character(), deregistered = logical()
  )
}
