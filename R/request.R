#' Base URL for a brreg API service
#'
#' Both services share the `data.brreg.no` host but live under different
#' path roots: the Enhetsregisteret REST API and the Fullmakt (signature
#' and procuration) service.
#'
#' @param service One of `"enhetsregisteret"` or `"fullmakt"`.
#' @keywords internal
brreg_base_url <- function(service = c("enhetsregisteret", "fullmakt")) {
  service <- match.arg(service)
  switch(
    service,
    enhetsregisteret = "https://data.brreg.no/enhetsregisteret/api",
    fullmakt         = "https://data.brreg.no/fullmakt"
  )
}

#' Remove NULL elements from a list
#' @keywords internal
compact <- function(x) x[!vapply(x, is.null, logical(1))]

#' Build an httr2 request with the shared tidybrreg configuration
#'
#' Centralises the user agent, transient-retry policy, and per-host
#' throttle so every request the package makes is constructed
#' identically. Host-specific concerns (base URL, throttle realm, Accept
#' header, error body extractor) are supplied by the caller.
#'
#' @param base_url Host base URL.
#' @param path URL path appended to `base_url`.
#' @param query Named list of query parameters.
#' @param realm Throttle realm. One bucket per host so distinct hosts do
#'   not share a rate limit.
#' @param rate Maximum sustained requests per second for `realm`.
#' @param accept Value of the `Accept` header.
#' @param error_body Optional function mapping a response to error
#'   messages, passed to [httr2::req_error()].
#' @keywords internal
brreg_http_req <- function(base_url, path, query = list(), realm,
                           rate = 5,
                           accept = "application/json;charset=UTF-8",
                           error_body = NULL) {
  req <- httr2::request(base_url) |>
    httr2::req_url_path_append(path) |>
    httr2::req_url_query(!!!compact(query)) |>
    httr2::req_user_agent("tidybrreg (https://github.com/sondreskarsten/tidybrreg; R package)") |>
    httr2::req_headers(Accept = accept) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 503)
    ) |>
    httr2::req_throttle(rate = rate, realm = realm)
  if (!is.null(error_body)) {
    req <- httr2::req_error(req, body = error_body)
  }
  req
}

#' Build an httr2 request to a brreg API service
#' @param path URL path appended to the base URL.
#' @param query Named list of query parameters.
#' @param service One of `"enhetsregisteret"` or `"fullmakt"`.
#' @keywords internal
brreg_req <- function(path, query = list(),
                      service = c("enhetsregisteret", "fullmakt")) {
  service <- match.arg(service)
  brreg_http_req(
    base_url   = brreg_base_url(service),
    path       = path,
    query      = query,
    realm      = "data.brreg.no",
    rate       = 5,
    error_body = brreg_error_body
  )
}

#' Build an httr2 request to the SSB KLASS API
#' @param path URL path appended to the base URL.
#' @param query Named list of query parameters.
#' @keywords internal
klass_req <- function(path, query = list()) {
  brreg_http_req(
    base_url = "https://data.ssb.no/api/klass/v1",
    path     = path,
    query    = query,
    realm    = "data.ssb.no",
    rate     = 5,
    accept   = "application/json"
  )
}

#' Extract error messages from brreg API error responses
#' @param resp An httr2 response object.
#' @keywords internal
brreg_error_body <- function(resp) {
  body <- tryCatch(httr2::resp_body_json(resp), error = \(e) list())
  msgs <- character()
  if (!is.null(body$validationErrors))
    msgs <- vapply(body$validationErrors, \(e) e$errorMessage, character(1))
  if (!is.null(body$error))
    msgs <- c(msgs, body$error)
  if (!is.null(body$trace))
    msgs <- c(msgs, paste("trace:", body$trace))
  msgs
}

#' Convert a string from camelCase or dot.notation to snake_case
#' @param x Character vector.
#' @keywords internal
to_snake <- function(x) {
  x <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  x <- gsub("\\.", "_", x)
  tolower(x)
}
