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

test_that("role_groups has required structure", {
  expect_s3_class(role_groups, "tbl_df")
  expect_gt(nrow(role_groups), 6)
  expect_true("STYR" %in% role_groups$code)
  expect_equal(unname(role_groups$name_en[role_groups$code == "STYR"]), "Board of Directors")
})
