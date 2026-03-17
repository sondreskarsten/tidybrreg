test_that("entity fixture parses to correct structure", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/entity_923609016.json"),
                              simplifyVector = TRUE)
  result <- tidybrreg:::parse_entity(json)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$org_nr, "923609016")
  expect_true("name" %in% names(result))
  expect_true("legal_form" %in% names(result))
  expect_true("employees" %in% names(result))
  expect_true("founding_date" %in% names(result))
  expect_s3_class(result$founding_date, "Date")
  expect_type(result$employees, "integer")
})

test_that("entity fixture has all field_dict columns", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/entity_923609016.json"),
                              simplifyVector = TRUE)
  result <- tidybrreg:::parse_entity(json)
  dict_cols <- field_dict$col_name
  missing <- setdiff(dict_cols, names(result))
  expect_equal(length(missing), 0,
    info = paste("Missing:", paste(missing, collapse = ", ")))
})

test_that("entity fixture label translation works", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/entity_923609016.json"),
                              simplifyVector = TRUE)
  result <- tidybrreg:::parse_entity(json)
  labelled <- brreg_label(result)
  expect_true(any(grepl("company|limited", labelled$legal_form, ignore.case = TRUE)))
})

test_that("search fixture parses to multi-row tibble", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/search_asa_5.json"),
                              simplifyVector = FALSE)
  items <- json[["_embedded"]][["enheter"]]
  expect_true(length(items) > 0)
  result <- tidybrreg:::parse_entities(items)
  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) > 0)
  expect_true("org_nr" %in% names(result))
})

test_that("search fixture page metadata is present", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/search_asa_5.json"),
                              simplifyVector = FALSE)
  expect_true(!is.null(json$page))
  expect_true(!is.null(json$page$totalElements))
  expect_true(json$page$totalElements > 0)
})

test_that("roles fixture parses to flat tibble", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/roles_923609016.json"),
                              simplifyVector = FALSE)
  result <- tidybrreg:::flatten_roles(json, "923609016")
  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) > 0)
  expect_true(all(c("org_nr", "role_group", "role") %in% names(result)))
  expect_true(all(result$org_nr == "923609016"))
})

test_that("roles fixture board_summary works", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/roles_923609016.json"),
                              simplifyVector = FALSE)
  roles <- tidybrreg:::flatten_roles(json, "923609016")
  summary <- brreg_board_summary(roles)
  expect_s3_class(summary, "tbl_df")
  expect_equal(nrow(summary), 1)
  expect_true("board_size" %in% names(summary))
  expect_true(summary$board_size > 0)
})

test_that("entity fixture types are correct after coercion", {
  json <- jsonlite::fromJSON(test_path("fixtures/mock/entity_923609016.json"),
                              simplifyVector = TRUE)
  result <- tidybrreg:::parse_entity(json)
  expect_type(result$org_nr, "character")
  expect_type(result$name, "character")
  expect_type(result$employees, "integer")
  expect_type(result$bankrupt, "logical")
  expect_s3_class(result$founding_date, "Date")
  expect_s3_class(result$registration_date, "Date")
})
