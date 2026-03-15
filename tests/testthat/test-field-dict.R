test_that("field_dict has required structure", {
  expect_s3_class(field_dict, "tbl_df")
  expect_true(all(c("api_path", "col_name", "type") %in% names(field_dict)))
  expect_gt(nrow(field_dict), 40)
})

test_that("field_dict has no duplicates", {
  expect_false(anyDuplicated(field_dict$col_name) > 0)
  expect_false(anyDuplicated(field_dict$api_path) > 0)
})

test_that("field_dict types are valid", {
  valid_types <- c("character", "Date", "integer", "logical")
  expect_true(all(field_dict$type %in% valid_types))
})

test_that("field_dict contains core columns", {
  core <- c("org_nr", "name", "legal_form", "employees", "founding_date",
            "nace_1", "municipality_code", "bankrupt", "parent_org_nr")
  expect_true(all(core %in% field_dict$col_name))
})
