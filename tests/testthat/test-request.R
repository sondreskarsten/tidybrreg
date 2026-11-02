test_that("brreg_req sets custom user-agent with package URL", {
  req <- tidybrreg:::brreg_req("enheter")
  ua <- req$options$useragent
  expect_true(grepl("tidybrreg", ua, ignore.case = TRUE))
  expect_true(grepl("github.com", ua))
})

test_that("brreg_req sets Accept header to JSON", {
  req <- tidybrreg:::brreg_req("enheter")
  expect_equal(req$headers$Accept, "application/json;charset=UTF-8")
})

test_that("brreg_req builds correct URL from path", {
  req <- tidybrreg:::brreg_req("enheter/923609016")
  expect_true(grepl("data.brreg.no/enhetsregisteret/api/enheter/923609016", req$url))
})

test_that("brreg_req applies query parameters", {
  req <- tidybrreg:::brreg_req("enheter", query = list(navn = "Equinor", size = 5))
  expect_true(grepl("navn=Equinor", req$url))
  expect_true(grepl("size=5", req$url))
})

test_that("brreg_req compact removes NULL query params", {
  req <- tidybrreg:::brreg_req("enheter", query = list(navn = "Equinor", size = NULL))
  expect_true(grepl("navn=Equinor", req$url))
  expect_false(grepl("size=", req$url))
})

test_that("brreg_req configures retry", {
  req <- tidybrreg:::brreg_req("enheter")
  expect_true("retry_max_tries" %in% names(req$policies))
  expect_true(req$policies$retry_max_tries >= 2)
})

test_that("the retry rule treats 429, 503, 500, 502 and 504 as transient", {
  mk <- function(status, body = "{}", type = "application/json") {
    httr2::response(status_code = status, headers = list(`Content-Type` = type), body = charToRaw(body))
  }
  for (s in c(429L, 503L, 500L, 502L, 504L)) expect_true(tidybrreg:::is_transient_response(mk(s)), info = s)
  for (s in c(200L, 400L, 404L, 410L)) expect_false(tidybrreg:::is_transient_response(mk(s)), info = s)
})

test_that("the unsupported-plan 500 is final, not transient", {
  resp <- httr2::response(status_code = 500L, headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"status":500,"message":"Regnskap har oppstillingsplan som ikke er st\u00f8ttet (BANK)"}'))
  expect_false(tidybrreg:::is_transient_response(resp))
  expect_match(tidybrreg:::unsupported_plan_message(resp), "BANK")
  other <- httr2::response(status_code = 500L, headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"status":500,"message":"Internal Server Error"}'))
  expect_true(tidybrreg:::is_transient_response(other))
  expect_true(is.na(tidybrreg:::unsupported_plan_message(other)))
})

test_that("a rate limit answered as HTTP 200 is transient and, when it persists, a typed error", {
  limited <- httr2::response(status_code = 200L, headers = list(`Content-Type` = "text/plain;charset=UTF-8"),
                             body = charToRaw("Too many requests"))
  expect_true(tidybrreg:::is_rate_limit_text(limited))
  expect_true(tidybrreg:::is_transient_response(limited))
  ok <- httr2::response(status_code = 200L, headers = list(`Content-Type` = "application/json"),
                        body = charToRaw('{"organisasjonsnummer":"923609016"}'))
  expect_false(tidybrreg:::is_rate_limit_text(ok))
  httr2::local_mocked_responses(function(req) limited)
  err <- expect_error(brreg_entity("923609016"), class = "tidybrreg_error_rate_limited")
  expect_equal(err$status, 200L)
  expect_match(err$url, "enheter/923609016")
})

test_that("a connection failure on every attempt is a typed error after the retries", {
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    rlang::abort("Could not resolve host", class = "httr2_failure")
  })
  testthat::local_mocked_bindings(Sys.sleep = function(time) NULL, .package = "base")
  err <- expect_error(brreg_entity("923609016"), class = "tidybrreg_error_connection")
  expect_equal(calls, 3L)
  expect_equal(err$attempts, 3L)
})

test_that("brreg_req configures throttling", {
  req <- tidybrreg:::brreg_req("enheter")
  policy_names <- names(req$policies)
  has_throttle <- any(grepl("throttle", policy_names))
  expect_true(has_throttle)
})

test_that("brreg_req configures structured error handler", {
  req <- tidybrreg:::brreg_req("enheter")
  expect_true("error_body" %in% names(req$policies))
  expect_true(is.function(req$policies$error_body))
})

test_that("brreg_error_body extracts validation errors from JSON", {
  body <- list(
    error = "Bad Request",
    validationErrors = list(
      list(errorMessage = "Invalid org number format")
    ),
    trace = "abc-123"
  )
  msgs <- character()
  if (!is.null(body$validationErrors))
    msgs <- vapply(body$validationErrors, \(e) e$errorMessage, character(1))
  if (!is.null(body$error))
    msgs <- c(msgs, body$error)
  if (!is.null(body$trace))
    msgs <- c(msgs, paste("trace:", body$trace))

  expect_true(any(grepl("Invalid org number", msgs)))
  expect_true(any(grepl("Bad Request", msgs)))
  expect_true(any(grepl("trace:", msgs)))
})

test_that("the bulk download retries a dropped connection and then aborts typed", {
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    rlang::abort("Recv failure: Connection reset by peer", class = "httr2_failure")
  })
  testthat::local_mocked_bindings(Sys.sleep = function(time) NULL, .package = "base")
  err <- expect_error(brreg_download("underenheter", cache = FALSE, type_output = "path"),
                      class = "tidybrreg_error_connection")
  expect_equal(calls, 3L)
  expect_match(err$url, "underenheter/lastned")
})

test_that("the bulk download aborts with the typed HTTP error on a server failure", {
  httr2::local_mocked_responses(function(req) httr2::response(status_code = 503))
  testthat::local_mocked_bindings(Sys.sleep = function(time) NULL, .package = "base")
  err <- expect_error(brreg_download("underenheter", cache = FALSE, type_output = "path"),
                      class = "tidybrreg_error_http")
  expect_equal(err$status, 503L)
})
