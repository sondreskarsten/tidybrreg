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
