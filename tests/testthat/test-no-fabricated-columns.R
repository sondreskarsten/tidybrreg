# A column absent on a given day must not be fabricated; code must
# handle it when present. Emission is batch-scoped: a column appears
# when the field is observed anywhere in the batch, NA within.

test_that("rename_from_dict omits dict fields absent from the response", {
  flat <- list(organisasjonsnummer = "923609016", navn = "EQUINOR ASA")
  res <- rename_from_dict(flat)
  expect_equal(res$org_nr, "923609016")
  expect_equal(res$name, "EQUINOR ASA")
  expect_false("capital_amount" %in% names(res))
  expect_false("bankrupt" %in% names(res))
  expect_lt(ncol(res), nrow(tidybrreg:::field_dict))
})

test_that("rename_from_dict keeps observed fields including falsy values", {
  flat <- list(organisasjonsnummer = "923609016", konkurs = FALSE)
  res <- rename_from_dict(flat)
  expect_true("bankrupt" %in% names(res))
  expect_false(res$bankrupt)
})

test_that("parse_entities unions columns across a batch", {
  raw <- list(
    list(organisasjonsnummer = "111111111", navn = "A", konkurs = FALSE),
    list(organisasjonsnummer = "222222222", navn = "B",
         kapital = list(belop = 1000))
  )
  res <- parse_entities(raw)
  expect_equal(nrow(res), 2L)
  expect_true("bankrupt" %in% names(res))
  expect_true(is.na(res$bankrupt[2]))
  expect_false(res$bankrupt[1])
})

test_that("rename_and_coerce does not fabricate absent bulk columns", {
  dat <- tibble::tibble(
    organisasjonsnummer = "923609016",
    navn = "EQUINOR ASA",
    konkurs = "true"
  )
  res <- rename_and_coerce(dat)
  out <- if (is.list(res) && "data" %in% names(res)) res$data else res
  expect_true(all(c("org_nr", "name", "bankrupt") %in% names(out)))
  expect_true(out$bankrupt)
  expect_false("capital_amount" %in% names(out))
  expect_equal(ncol(out), 3L)
})

test_that("rename_and_coerce still coerces the columns that are present", {
  dat <- tibble::tibble(
    organisasjonsnummer = "923609016",
    registreringsdatoEnhetsregisteret = "1995-02-19",
    antallAnsatte = "21000"
  )
  res <- rename_and_coerce(dat)
  out <- if (is.list(res) && "data" %in% names(res)) res$data else res
  expect_s3_class(out$registration_date, "Date")
  expect_type(out$employees, "integer")
  expect_equal(out$employees, 21000L)
})
