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

test_that("brreg_label translates regnskap items, groups and statements in both languages", {
  expect_equal(brreg_label(c("total_assets", "net_income", "zzz"), dic = "regnskap_item"),
               c("Total assets", "Net income", "zzz"))
  expect_equal(brreg_label(c("total_assets", "net_income"), dic = "regnskap_item", lang = "no"),
               c("Sum eiendeler", "\u00c5rsresultat"))
  expect_equal(brreg_label(c("assets", "operating"), dic = "regnskap_group", lang = "no"),
               c("Eiendeler", "Driftsresultat"))
  items <- tibble::tibble(statement = "assets", group = "current_assets",
                          item = "total_assets", value = 1)
  out <- brreg_label(items, code = "item")
  expect_equal(out$item_code, "total_assets")
  expect_equal(out$item, "Total assets")
  expect_equal(out$group, "Current assets")
  expect_equal(out$statement, "Assets")
})

test_that("brreg_label descends into the nested items of brreg_regnskap", {
  acc <- flatten_regnskap(jsonlite::read_json(test_path("fixtures", "regnskap_release_2026-10.json")), "923609016")
  lab <- brreg_label(acc, lang = "no")
  expect_equal(nrow(lab), nrow(acc))
  expect_true(all(vapply(lab$items, is.data.frame, logical(1))))
  first <- lab$items[[1]]
  expect_true("Sum eiendeler" %in% first$item)
  expect_false("total_assets" %in% first$item)
  expect_true(all(first$path == acc$items[[1]]$path))
  expect_equal(lab$legal_form, brreg_label(acc$legal_form, dic = "legal_form", lang = "no"))
  expect_identical(brreg_label(lab, lang = "no"), lab)
})

test_that("brreg_label handles empty data frame", {
  df <- tibble::tibble(legal_form = character(0))
  result <- brreg_label(df)
  expect_equal(nrow(result), 0)
})

test_that("brreg_label requires dic for vectors", {
  expect_error(brreg_label(c("AS", "ASA")), "dic")
})
