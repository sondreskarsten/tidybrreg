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

test_that("brreg_req configures throttling", {
  req <- tidybrreg:::brreg_req("enheter")
  expect_true("throttle_realm" %in% names(req$policies))
  expect_true(grepl("brreg", req$policies$throttle_realm))
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
