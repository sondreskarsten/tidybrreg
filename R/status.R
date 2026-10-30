#' Map the status of a satellite endpoint response to a result
#'
#' The per-entity satellite endpoints (roles, legal roles, konsern,
#' signatur, prokura) share one status contract, documented in
#' [brreg_roles()]: HTTP 200 is parsed by the caller; HTTP 404 (the entity
#' does not exist, or has nothing registered at this endpoint) yields the
#' typed empty result with attribute `http_status = 404L` and no warning;
#' HTTP 410 yields the typed empty with `http_status = 410L` and a
#' `tidybrreg_warning_deleted`; any other status of 400 or above aborts
#' with a `tidybrreg_error_http`.
#'
#' @param resp An httr2 response.
#' @param endpoint Requested path, for condition fields.
#' @param org_nr Organization number, for condition fields.
#' @param empty The typed zero-row tibble for the endpoint.
#' @returns `NULL` when the caller should parse the body, otherwise the
#'   result to return.
#' @keywords internal
satellite_status <- function(resp, endpoint, org_nr, empty,
                             call = rlang::caller_env()) {
  status <- httr2::resp_status(resp)
  if (status == 200L) return(NULL)
  if (status == 404L) {
    attr(empty, "http_status") <- 404L
    return(empty)
  }
  if (status == 410L) {
    body <- tryCatch(httr2::resp_body_json(resp), error = \(e) list())
    deletion_date <- parse_brreg_date(body$slettedato %||% NA_character_)
    brreg_warn(
      "Entity {.val {org_nr}} was deleted on {format(deletion_date)}.",
      class = "deleted", org_nr = org_nr, deletion_date = deletion_date,
      call = call
    )
    attr(empty, "http_status") <- 410L
    attr(empty, "deletion_date") <- deletion_date
    return(empty)
  }
  abort_http(resp, endpoint, call = call)
}
