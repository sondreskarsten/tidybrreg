#' Retrieve the corporate group structure (konsernstruktur)
#'
#' Fetch the registered group hierarchy for a Norwegian legal entity
#' from the Enhetsregisteret konsernstruktur endpoint (added by BRREG
#' 2026-06-24). The tree is returned flat: one row per node, root
#' included at `level = 0`, each child carrying its link form
#' (`knytningsform`, e.g. `KDAT` "Konsern datter"), ownership basis
#' (`grunnlag`, e.g. `"100%"`), and the registration date of the
#' relation.
#'
#' The JSON response omits `knytningsform` on the root node while the
#' API's CSV variant emits it as `KKKK` "Øverste mor"; the root row is
#' synthesized here to match the CSV semantics.
#'
#' This is the ownership hierarchy and is distinct from
#' [brreg_children()], which searches `overordnetEnhet` — the
#' administrative parent relation used in public-sector (ORGL)
#' structures, not konsern ownership.
#'
#' @section 404 semantics:
#' The endpoint returns 404 both for organization numbers that do not
#' exist and for live entities that are not part of any registered
#' group — the common case for ordinary companies. The
#' `in_corporate_group` column from [brreg_entity()] disambiguates the
#' two without a second lookup here.
#'
#' @inheritSection brreg_roles Status handling
#'
#' @param org_nr Character. A single 9-digit organization number.
#'
#' @returns A tibble with one row per node in the group tree.
#'   Columns: `org_nr` (the queried entity), `node_org_nr`,
#'   `node_name`, `level` (0 for the root), `link_form`,
#'   `link_form_desc`, `basis`, `relation_date` (Date),
#'   `parent_org_nr`, `parent_name`, `legal_form`, `legal_form_desc`.
#'   A zero-row tibble with the same typed columns if no group
#'   structure is registered.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_children()] for the ORGL administrative hierarchy,
#'   [brreg_entity()] for the `in_corporate_group` flag,
#'   [brreg_roles_legal()] for roles an entity holds in others.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_konsern("923609016") # Equinor ASA
brreg_konsern <- function(org_nr) {
  org_nr <- check_org_nr(org_nr)
  endpoint <- paste0("konsernstruktur/", org_nr)
  resp <- brreg_perform(brreg_req(endpoint))
  out <- satellite_status(resp, endpoint, org_nr, empty_konsern())
  if (!is.null(out)) return(out)
  flatten_konsern(httr2::resp_body_json(resp), org_nr)
}

#' Typed zero-row tibble for konsern results
#' @keywords internal
empty_konsern <- function() {
  tibble::tibble(
    org_nr = character(), node_org_nr = character(), node_name = character(),
    level = integer(), link_form = character(), link_form_desc = character(),
    basis = character(), relation_date = as.Date(character()),
    parent_org_nr = character(), parent_name = character(),
    legal_form = character(), legal_form_desc = character()
  )
}


#' Flatten a recursive konsernstruktur response to one row per node
#'
#' Unlike the depth-2-bounded structures elsewhere in the package
#' (roles, signatur), the konsern tree nests `children` to arbitrary
#' depth, so this walks recursively, reusing the recursive-helper +
#' emit-callback shape of [flatten_value_into()]. Observed values win
#' over derived ones: `nivaa`, `parentOrganisasjonsnummer`, and
#' `parentNavn` are taken from the node when present and only filled
#' from recursion context when absent (the root). `dato` is accepted in
#' both ISO and `DD.MM.YYYY` form via [parse_brreg_date()].
#'
#' @param raw Parsed JSON list from the konsernstruktur endpoint.
#' @param org_nr Organization number (passed through to output).
#' @keywords internal
flatten_konsern <- function(raw, org_nr) {
  rows <- list()
  k <- 0L
  emit <- function(node, depth, parent_org, parent_name) {
    k <<- k + 1L
    is_root <- depth == 0L
    rows[[k]] <<- tibble::tibble(
      org_nr          = org_nr,
      node_org_nr     = node$organisasjonsnummer %||% NA_character_,
      node_name       = node$navn %||% NA_character_,
      level           = as.integer(node$nivaa %||% depth),
      link_form       = node$knytningsform$kode %||%
                          if (is_root) "KKKK" else NA_character_,
      link_form_desc  = node$knytningsform$beskrivelse %||%
                          if (is_root) "\u00d8verste mor" else NA_character_,
      basis           = node$grunnlag %||% NA_character_,
      relation_date   = node$dato %||% NA_character_,
      parent_org_nr   = node$parentOrganisasjonsnummer %||% parent_org,
      parent_name     = node$parentNavn %||% parent_name,
      legal_form      = node$organisasjonsform$kode %||% NA_character_,
      legal_form_desc = node$organisasjonsform$beskrivelse %||% NA_character_
    )
    for (ch in (node$children %||% list())) {
      emit(ch, depth + 1L,
           node$organisasjonsnummer %||% NA_character_,
           node$navn %||% NA_character_)
    }
  }
  emit(raw, 0L, NA_character_, NA_character_)
  result <- dplyr::bind_rows(rows[seq_len(k)])
  result$relation_date <- parse_brreg_date(result$relation_date)
  result
}
