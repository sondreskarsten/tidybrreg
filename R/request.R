#' @keywords internal
brreg_base_url <- function() "https://data.brreg.no/enhetsregisteret/api"

#' Remove NULL elements from a list
#' @keywords internal
compact <- function(x) x[!vapply(x, is.null, logical(1))]

#' Build an httr2 request to the brreg API
#' @param path URL path appended to the base URL.
#' @param query Named list of query parameters.
#' @keywords internal
brreg_req <- function(path, query = list()) {
  httr2::request(brreg_base_url()) |>
    httr2::req_url_path_append(path) |>
    httr2::req_url_query(!!!compact(query)) |>
    httr2::req_user_agent("tidybrreg (https://github.com/sondreskarsten/tidybrreg; R package)") |>
    httr2::req_headers(Accept = "application/json;charset=UTF-8") |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429, 503)
    ) |>
    httr2::req_throttle(rate = 5, realm = "data.brreg.no") |>
    httr2::req_error(body = brreg_error_body)
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
