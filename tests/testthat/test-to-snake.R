# Regression tests for to_snake() — custom camelCase/dot.notation converter.
# Audit benchmarked against janitor::clean_names() and snakecase::to_snake_case().
# Custom impl is justified for this package's specific patterns but must handle
# the brreg API's actual field names correctly.

test_that("to_snake converts camelCase", {
  expect_equal(tidybrreg:::to_snake("antallAnsatte"), "antall_ansatte")
  expect_equal(tidybrreg:::to_snake("organisasjonsnummer"), "organisasjonsnummer")
  expect_equal(tidybrreg:::to_snake("stiftelsesdato"), "stiftelsesdato")
})

test_that("to_snake converts dot.notation", {
  expect_equal(tidybrreg:::to_snake("forretningsadresse.kommune"), "forretningsadresse_kommune")
  expect_equal(tidybrreg:::to_snake("organisasjonsform.kode"), "organisasjonsform_kode")
})

test_that("to_snake handles mixed camelCase and dots", {
  expect_equal(tidybrreg:::to_snake("forretningsadresse.postSted"), "forretningsadresse_post_sted")
})

test_that("to_snake handles consecutive capitals", {
  expect_equal(tidybrreg:::to_snake("overordnetEnhet"), "overordnet_enhet")
  expect_equal(tidybrreg:::to_snake("vedtektsfestetFormaal"), "vedtektsfestet_formaal")
})

test_that("to_snake lowercases everything", {
  expect_equal(tidybrreg:::to_snake("ASA"), "asa")
  expect_equal(tidybrreg:::to_snake("NUF"), "nuf")
})

test_that("to_snake is idempotent on already-snake strings", {
  expect_equal(tidybrreg:::to_snake("org_nr"), "org_nr")
  expect_equal(tidybrreg:::to_snake("founding_date"), "founding_date")
  expect_equal(tidybrreg:::to_snake("municipality_code"), "municipality_code")
})

test_that("to_snake handles real brreg API field names", {
  brreg_fields <- c(
    "naeringskode1.kode", "naeringskode2.kode", "naeringskode3.kode",
    "forretningsadresse.postnummer", "postadresse.poststed",
    "registrertIForetaksregisteret", "registrertIStiftelsesregisteret",
    "harRegistrertAntallAnsatte", "frivilligMvaRegistrertBeskrivelser"
  )
  results <- tidybrreg:::to_snake(brreg_fields)
  expect_true(all(results == tolower(results)))
  expect_false(any(grepl("\\.", results)))
})
