#' Base URL for a brreg API service
#'
#' The services share the `data.brreg.no` host but live under different
#' path roots: the Enhetsregisteret REST API, the Fullmakt (signature
#' and procuration) service and the Regnskapsregisteret accounts API.
#'
#' @param service One of `"enhetsregisteret"`, `"fullmakt"` or
#'   `"regnskapsregisteret"`.
#' @keywords internal
brreg_base_url <- function(service = c("enhetsregisteret", "fullmakt",
                                       "regnskapsregisteret")) {
  service <- match.arg(service)
  switch(
    service,
    enhetsregisteret    = "https://data.brreg.no/enhetsregisteret/api",
    fullmakt            = "https://data.brreg.no/fullmakt",
    regnskapsregisteret = "https://data.brreg.no/regnskapsregisteret/regnskap"
  )
}

#' Remove NULL elements from a list
#' @keywords internal
compact <- function(x) x[!vapply(x, is.null, logical(1))]

#' The user agent every tidybrreg request carries
#' @keywords internal
brreg_user_agent <- function() {
  "tidybrreg (https://github.com/sondreskarsten/tidybrreg; R package)"
}

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
    httr2::req_user_agent(brreg_user_agent()) |>
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
#' @param service One of `"enhetsregisteret"`, `"fullmakt"` or
#'   `"regnskapsregisteret"`.
#' @keywords internal
brreg_req <- function(path, query = list(),
                      service = c("enhetsregisteret", "fullmakt",
                                  "regnskapsregisteret")) {
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

#' Perform a brreg request without raising on HTTP error status
#'
#' Every endpoint wrapper inspects the status itself so that 404, 410 and
#' server errors can be mapped to the typed conditions documented in
#' [tidybrreg_conditions]. The retry policy of [brreg_http_req()] still
#' applies.
#' @param req An httr2 request.
#' @keywords internal
brreg_perform <- function(req) {
  req |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
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
#'
#' Enhetsregisteret answers a rejected request with a Norwegian error
#' body (`feilmelding`, `valideringsfeil[].feilmelding` with the
#' offending `parametere`); older and other services use
#' `validationErrors[].errorMessage`, `error` and `trace`. Every form
#' is read so the `tidybrreg_error_http` carries what the register said.
#' @param resp An httr2 response object.
#' @keywords internal
brreg_error_body <- function(resp) {
  body <- tryCatch(httr2::resp_body_json(resp), error = \(e) list())
  msgs <- character()
  if (!is.null(body$valideringsfeil))
    msgs <- vapply(body$valideringsfeil, \(e) {
      params <- paste(unlist(e$parametere), collapse = ", ")
      if (nzchar(params)) paste0(e$feilmelding, " (", params, ")") else e$feilmelding
    }, character(1))
  if (!is.null(body$validationErrors))
    msgs <- c(msgs, vapply(body$validationErrors, \(e) e$errorMessage, character(1)))
  if (!is.null(body$feilmelding) && length(msgs) == 0)
    msgs <- c(msgs, body$feilmelding)
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

# ---------------------------------------------------------------------------
# Conditions
# ---------------------------------------------------------------------------

#' Conditions signalled by tidybrreg
#'
#' Every error and warning raised by the package carries a class that can
#' be caught with [tryCatch()] or silenced with [suppressWarnings()]
#' selectively, and a set of fields describing the request that produced
#' it. All classes inherit from `tidybrreg_error` or `tidybrreg_warning`.
#'
#' @section Errors:
#' - `tidybrreg_error_invalid_org_nr`: the organization number failed
#'   [brreg_validate()]. Field `org_nr`.
#' - `tidybrreg_error_invalid_filter`: a filter is not supported by the
#'   requested registry (for example `bankrupt` on `underenheter`). Fields
#'   `registry`, `filter`.
#' - `tidybrreg_error_not_found`: the endpoint answered HTTP 404 for an
#'   organization number. Fields `org_nr`, `endpoint`, `status`.
#' - `tidybrreg_error_http`: any other HTTP status of 400 or above, or a
#'   failure on the first page of a paginated request. Fields `endpoint`,
#'   `status`, `messages` (as extracted from the BRREG error body).
#' - `tidybrreg_error_result_window`: the query matches more entities than
#'   BRREG's search window can deliver and the request asked for more than
#'   the window. Fields `endpoint`, `total_matches`, `retrieval_limit`,
#'   `filters`. See [brreg_search()].
#'
#' @section Warnings:
#' - `tidybrreg_warning_deleted`: the entity has been deleted from the
#'   register (HTTP 410, or HTTP 200 with `respons_klasse`
#'   `"SlettetEnhet"`). Fields `org_nr`, `deletion_date`.
#' - `tidybrreg_warning_partial`: a paginated request failed after at least
#'   one page was retrieved; the partial result is returned with
#'   attribute `complete = FALSE`. Fields `endpoint`, `status`,
#'   `pages_fetched`.
#' - `tidybrreg_warning_truncated`: more results exist than were returned
#'   because of `max_results` or `max_pages`; the result carries attribute
#'   `complete = FALSE`. Fields `endpoint`, `returned`, `total_matches`.
#' - `tidybrreg_warning_unknown_member`: an update feed carried a member
#'   the package does not model; it is passed through unchanged. Field
#'   `members`.
#' - `tidybrreg_warning_bundled_fallback`: SSB KLASS was unreachable and a
#'   bundled dictionary was used instead. Fields `dictname`, `vintage`.
#' - `tidybrreg_warning_unsupported_plan`: Regnskapsregisteret does not
#'   serve the entity's accounting plan (banks, insurers, pension funds);
#'   the typed empty result carries `http_status = 500L` and
#'   `unsupported_plan`. Fields `org_nr`, `plan`, `api_message`. See
#'   [brreg_regnskap()].
#' - `tidybrreg_warning_parse`: values could not be coerced to the type
#'   declared in [field_dict]; the result carries attribute
#'   `brreg_parse_problems`. Field `n`.
#'
#' @name tidybrreg_conditions
#' @family tidybrreg utilities
#' @examples
#' tryCatch(
#'   brreg_entity("123456789"),
#'   tidybrreg_error_invalid_org_nr = function(e) e$org_nr
#' )
NULL

#' Signal a typed tidybrreg error
#' @param message A cli-formatted message vector.
#' @param class Condition subclass (without the `tidybrreg_error_` prefix).
#' @param ... Fields stored on the condition object.
#' @param call Calling environment reported by cli.
#' @param .envir Environment in which the message's `{}` expressions are
#'   evaluated; defaults to the caller of this helper.
#' @keywords internal
brreg_abort <- function(message, class, ..., call = rlang::caller_env(),
                        .envir = parent.frame()) {
  cli::cli_abort(
    message,
    class = c(paste0("tidybrreg_error_", class), "tidybrreg_error"),
    ...,
    call = call,
    .envir = .envir
  )
}

#' Signal a typed tidybrreg warning
#' @inheritParams brreg_abort
#' @keywords internal
brreg_warn <- function(message, class, ..., call = rlang::caller_env(),
                       .envir = parent.frame()) {
  cli::cli_warn(
    message,
    class = c(paste0("tidybrreg_warning_", class), "tidybrreg_warning"),
    ...,
    call = call,
    .envir = .envir
  )
}

#' Abort on an HTTP error response
#' @param resp An httr2 response with status 400 or above.
#' @param endpoint Path that was requested (for the condition fields).
#' @keywords internal
abort_http <- function(resp, endpoint, call = rlang::caller_env()) {
  status <- httr2::resp_status(resp)
  msgs <- brreg_error_body(resp)
  brreg_abort(
    c("Norwegian Business Registry API error: HTTP {status} for {.path {endpoint}}.",
      stats::setNames(msgs, rep("x", length(msgs)))),
    class = "http", endpoint = endpoint, status = status, messages = msgs,
    call = call
  )
}

# ---------------------------------------------------------------------------
# Dates and instants
# ---------------------------------------------------------------------------

#' Parse a BRREG calendar date
#'
#' BRREG emits dates as ISO `YYYY-MM-DD` on the Enhetsregisteret API and
#' as `DD.MM.YYYY` on the Fullmakt service and in the CSV variant of the
#' konsernstruktur endpoint. Both forms are accepted; anything else
#' becomes `NA` and is counted by the caller as a parse problem.
#'
#' @param x Character vector.
#' @returns A `Date` vector of the same length.
#' @keywords internal
parse_brreg_date <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  out <- rep(as.Date(NA), length(x))
  iso <- grepl("^\\d{4}-\\d{2}-\\d{2}", x)
  out[iso] <- as.Date(substr(x[iso], 1L, 10L), format = "%Y-%m-%d")
  dotted <- grepl("^\\d{2}\\.\\d{2}\\.\\d{4}$", x)
  out[dotted] <- as.Date(x[dotted], format = "%d.%m.%Y")
  out
}

#' Parse an ISO 8601 instant as UTC
#'
#' BRREG timestamps (`dato` on the enheter/underenheter update feeds,
#' `time` on the roller CloudEvents feed) are UTC instants, with or
#' without fractional seconds and with or without a trailing `Z`. They
#' are parsed as UTC regardless of the session time zone so a value
#' round-trips identically on every machine.
#'
#' @param x Character vector.
#' @returns A `POSIXct` vector in the `UTC` time zone.
#' @keywords internal
parse_brreg_instant <- function(x) {
  x <- as.character(x)
  x <- sub("Z$", "", x)
  x <- sub("([+-]\\d{2}):?(\\d{2})$", "", x)
  out <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
  date_only <- is.na(out) & grepl("^\\d{4}-\\d{2}-\\d{2}$", x)
  out[date_only] <- as.POSIXct(x[date_only], format = "%Y-%m-%d", tz = "UTC")
  out
}

#' Format a `since` argument for the update feeds
#'
#' A `POSIXct` keeps its full precision and is rendered in UTC; a `Date`
#' is the start of that day in UTC; a character value is parsed with
#' [parse_brreg_instant()] (ISO date or date-time). The result is the
#' `YYYY-MM-DDTHH:MM:SS.sssZ` form the feeds expect.
#'
#' @param since Date, POSIXct, or character.
#' @returns A length-1 character string.
#' @keywords internal
format_since <- function(since) {
  if (inherits(since, "POSIXt")) {
    inst <- as.POSIXct(since)
  } else if (inherits(since, "Date")) {
    inst <- as.POSIXct(format(since, "%Y-%m-%d"), format = "%Y-%m-%d", tz = "UTC")
  } else {
    inst <- parse_brreg_instant(since)
    if (is.na(inst)) {
      brreg_abort(
        "{.arg since} must be a Date, POSIXct, or ISO 8601 string, not {.val {since}}.",
        class = "invalid_since", since = since
      )
    }
  }
  format(inst, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
}

#' Parse an HTTP-date header as UTC
#'
#' `Last-Modified` and `Date` headers use the RFC 7231 IMF-fixdate form,
#' which is always GMT. Parsed with the `C` locale so weekday and month
#' names are recognised regardless of the session locale.
#'
#' @param x Character vector of header values.
#' @returns A `POSIXct` vector in the `UTC` time zone.
#' @keywords internal
parse_http_date <- function(x) {
  if (is.null(x)) return(as.POSIXct(NA, tz = "UTC"))
  old <- Sys.getlocale("LC_TIME")
  on.exit(Sys.setlocale("LC_TIME", old), add = TRUE)
  Sys.setlocale("LC_TIME", "C")
  as.POSIXct(as.character(x), format = "%a, %d %b %Y %H:%M:%S", tz = "UTC")
}
