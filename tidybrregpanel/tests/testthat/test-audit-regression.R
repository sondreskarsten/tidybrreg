# Regression tests moved from the tidybrreg core suite (managed store parts).

test_that("resolve_snapshot_dates LOCF works without max_gap", {
  available <- as.Date(c("2024-01-01", "2024-07-01"))
  targets <- as.Date(c("2024-06-30", "2024-12-31", "2025-12-31"))
  result <- tidybrregpanel:::resolve_snapshot_dates(available, targets)

  expect_equal(result$snapshot_date[result$target_date == as.Date("2025-12-31")],
               as.Date("2024-07-01"))
})

test_that("parquet_tier returns a valid tier", {
  tier <- tidybrregpanel:::parquet_tier()
  expect_true(tier %in% c("arrow", "nanoparquet", "none"))
})

test_that("check_parquet_available uses cli error with package suggestions", {
  skip_if(tidybrregpanel:::parquet_tier() != "none")
  expect_error(tidybrregpanel:::check_parquet_available(), "parquet backend")
})

test_that("brreg_data_dir returns a character path", {
  result <- brreg_data_dir()
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})
