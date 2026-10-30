test_that("legal_forms has required structure", {
  expect_s3_class(legal_forms, "tbl_df")
  expect_true(all(c("code", "name_no", "name_en") %in% names(legal_forms)))
  expect_gt(nrow(legal_forms), 35)
})

test_that("legal_forms covers common codes", {
  common <- c("AS", "ASA", "ENK", "NUF", "ANS", "DA", "STI", "SA")
  expect_true(all(common %in% legal_forms$code))
})

test_that("legal_forms has English translations", {
  expect_true(all(!is.na(legal_forms$name_en)))
  expect_equal(unname(legal_forms$name_en[legal_forms$code == "AS"]), "Private limited company")
  expect_equal(unname(legal_forms$name_en[legal_forms$code == "ASA"]), "Public limited company")
})

test_that("role_types has required structure", {
  expect_s3_class(role_types, "tbl_df")
  expect_true(all(c("code", "name_en", "name_no") %in% names(role_types)))
  expect_gt(nrow(role_types), 12)
})

test_that("role_types covers common codes", {
  expect_true(all(c("LEDE", "MEDL", "DAGL", "REVI") %in% role_types$code))
  expect_equal(unname(role_types$name_en[role_types$code == "LEDE"]), "Chair of the Board")
  expect_equal(unname(role_types$name_en[role_types$code == "DAGL"]), "CEO / Managing Director")
})

test_that("regnskap_items labels every line item of regnskap_dict in both languages", {
  expect_s3_class(regnskap_items, "tbl_df")
  expect_named(regnskap_items, names(role_types))
  in_statement <- grepl("^(eiendeler|egenkapitalGjeld|resultatregnskapResultat)\\.", regnskap_dict$api_path)
  expect_setequal(regnskap_items$code, regnskap_dict$col_name[in_statement])
  expect_false(anyNA(regnskap_items$name_en))
  expect_false(anyNA(regnskap_items$name_no))
  expect_equal(regnskap_items$name_no[regnskap_items$code == "total_assets"], "Sum eiendeler")
  expect_equal(regnskap_items$name_en[regnskap_items$code == "net_income"], "Net income")
})

test_that("regnskap_groups names every grouping object and the three statements", {
  expect_s3_class(regnskap_groups, "tbl_df")
  expect_named(regnskap_groups, c("path", "code", "name_en", "name_no"))
  expect_false(anyDuplicated(regnskap_groups$path) > 0)
  expect_false(anyDuplicated(regnskap_groups$code) > 0)
  expect_equal(tidybrreg:::regnskap_statements(),
               c(eiendeler = "assets", egenkapitalGjeld = "equity_liabilities",
                 resultatregnskapResultat = "income_statement"))
  nodes <- unique(sub("\\.[^.]+$", "", regnskap_dict$api_path[grepl("^(eiendeler|egenkapitalGjeld|resultatregnskapResultat)\\.", regnskap_dict$api_path)]))
  expect_true(all(nodes %in% regnskap_groups$path))
})

test_that("role_groups has required structure", {
  expect_s3_class(role_groups, "tbl_df")
  expect_gt(nrow(role_groups), 6)
  expect_true("STYR" %in% role_groups$code)
  expect_equal(unname(role_groups$name_en[role_groups$code == "STYR"]), "Board of Directors")
})
