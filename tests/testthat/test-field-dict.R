test_that("field_dict has required structure", {
  expect_s3_class(field_dict, "tbl_df")
  expect_true(all(c("api_path", "col_name", "type") %in% names(field_dict)))
  expect_gt(nrow(field_dict), 40)
})

test_that("field_dict has no duplicates", {
  expect_false(anyDuplicated(field_dict$api_path) > 0)
})

test_that("field_dict types are valid", {
  valid_types <- c("character", "Date", "integer", "logical", "numeric")
  expect_true(all(field_dict$type %in% valid_types))
})

test_that("regnskap_dict has the structure and types of field_dict", {
  expect_s3_class(regnskap_dict, "tbl_df")
  expect_named(regnskap_dict, names(field_dict))
  expect_false(anyDuplicated(regnskap_dict$api_path) > 0)
  expect_false(anyDuplicated(regnskap_dict$col_name) > 0)
  expect_true(all(regnskap_dict$type %in% c("character", "Date", "integer", "logical", "numeric")))
  expect_true(all(c("org_nr", "filing_id", "account_type", "period_end", "currency", "total_assets", "net_income") %in% regnskap_dict$col_name))
})

test_that("field_dict contains core columns", {
  core <- c("org_nr", "name", "legal_form", "employees", "founding_date",
            "nace_1", "municipality_code", "bankrupt", "parent_org_nr")
  expect_true(all(core %in% field_dict$col_name))
})
