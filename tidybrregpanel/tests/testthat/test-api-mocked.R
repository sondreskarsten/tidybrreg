# Fixture-based tests for tidybrregpanel

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
