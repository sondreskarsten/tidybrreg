test_that("flatten_json handles nested JSON", {
  raw <- list(
    organisasjonsnummer = "923609016",
    navn = "TEST",
    organisasjonsform = list(kode = "AS", beskrivelse = "Aksjeselskap"),
    forretningsadresse = list(
      adresse = list("Street 1", "Floor 2"),
      postnummer = "0001",
      kommune = "OSLO"
    )
  )
  flat <- tidybrreg:::flatten_json(raw)
  expect_true("organisasjonsnummer" %in% names(flat))
  expect_true("organisasjonsform.kode" %in% names(flat))
  expect_true("forretningsadresse.postnummer" %in% names(flat))
  expect_equal(flat[["organisasjonsform.kode"]], "AS")
  expect_equal(flat[["forretningsadresse.adresse"]], "Street 1, Floor 2")
})

test_that("to_snake converts correctly", {
  expect_equal(tidybrreg:::to_snake("camelCase"), "camel_case")
  expect_equal(tidybrreg:::to_snake("organisasjonsform.kode"), "organisasjonsform_kode")
  expect_equal(tidybrreg:::to_snake("registreringsdatoEnhetsregisteret"), "registreringsdato_enhetsregisteret")
})

test_that("parse_entity maps known fields and passes through unknown", {
  raw <- list(
    organisasjonsnummer = "923609016",
    navn = "TEST AS",
    organisasjonsform = list(kode = "AS", beskrivelse = "Aksjeselskap"),
    antallAnsatte = 42,
    stiftelsesdato = "2020-01-15",
    konkurs = FALSE,
    unknownNewField = "surprise"
  )
  result <- tidybrreg:::parse_entity(raw)
  expect_s3_class(result, "tbl_df")
  expect_equal(result$org_nr, "923609016")
  expect_equal(result$name, "TEST AS")
  expect_equal(result$legal_form, "AS")
  expect_equal(result$employees, 42L)
  expect_s3_class(result$founding_date, "Date")
  expect_equal(result$bankrupt, FALSE)
  expect_true("unknown_new_field" %in% names(result))
})

test_that("rename_and_coerce guarantees all field_dict columns", {
  dat <- tibble::tibble(
    organisasjonsnummer = "923609016",
    navn = "TEST"
  )
  result <- tidybrreg:::rename_and_coerce(dat)

  expect_true("org_nr" %in% names(result))
  expect_true("name" %in% names(result))
  expect_true("founding_date" %in% names(result))
  expect_true("employees" %in% names(result))
  expect_true("purpose" %in% names(result))
  expect_true("activity" %in% names(result))
  expect_true("bankrupt" %in% names(result))

  expect_true(is.na(result$founding_date))
  expect_true(is.na(result$employees))
  expect_true(is.na(result$purpose))
  expect_true(is.na(result$activity))

  expect_s3_class(result$founding_date, "Date")
  expect_type(result$employees, "integer")
  expect_type(result$purpose, "character")
})

test_that("parse_bulk_json produces all field_dict columns even when absent from data", {
  json_data <- jsonlite::toJSON(list(
    list(organisasjonsnummer = "923609016", navn = "EQUINOR ASA",
         organisasjonsform = list(kode = "ASA"),
         antallAnsatte = 21408)
  ), auto_unbox = TRUE)

  tmp <- tempfile(fileext = ".json.gz")
  con <- gzfile(tmp, "w")
  writeLines(as.character(json_data), con)
  close(con)

  dat <- tidybrreg:::parse_bulk_json(tmp)

  expect_true("purpose" %in% names(dat))
  expect_true("activity" %in% names(dat))
  expect_true("founding_date" %in% names(dat))
  expect_true("bankrupt" %in% names(dat))

  expect_true(is.na(dat$purpose))
  expect_true(is.na(dat$activity))
  expect_equal(dat$employees, 21408L)
  expect_equal(dat$org_nr, "923609016")
  unlink(tmp)
})
