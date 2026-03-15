test_that("brreg_label translates legal_form codes", {
  df <- tibble::tibble(legal_form = c("AS", "ASA", "ENK"))
  result <- brreg_label(df)
  expect_equal(unname(result$legal_form[1]), "Private limited company")
  expect_equal(unname(result$legal_form[2]), "Public limited company")
  expect_equal(unname(result$legal_form[3]), "Sole proprietorship")
})

test_that("brreg_label code parameter preserves originals", {
  df <- tibble::tibble(legal_form = c("AS", "ASA"), nace_1 = c("06.100", "64.190"))
  result <- brreg_label(df, code = "legal_form")
  expect_true("legal_form_code" %in% names(result))
  expect_equal(result$legal_form_code, c("AS", "ASA"))
  expect_true(all(unname(result$legal_form) != c("AS", "ASA")))
})

test_that("brreg_label works on character vectors", {
  result <- brreg_label(c("AS", "ASA"), dic = "legal_form")
  expect_equal(unname(result[1]), "Private limited company")
  expect_equal(unname(result[2]), "Public limited company")
})

test_that("brreg_label passes through unknown codes", {
  result <- brreg_label(c("AS", "ZZZZZ"), dic = "legal_form")
  expect_equal(unname(result[2]), "ZZZZZ")
})

test_that("brreg_label handles empty data frame", {
  df <- tibble::tibble(legal_form = character(0))
  result <- brreg_label(df)
  expect_equal(nrow(result), 0)
})

test_that("brreg_label requires dic for vectors", {
  expect_error(brreg_label(c("AS", "ASA")), "dic")
})
