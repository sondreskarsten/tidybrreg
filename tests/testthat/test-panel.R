test_that("resolve_snapshot_dates uses LOCF", {
  available <- as.Date(c("2024-01-01", "2024-07-01", "2025-01-01"))
  targets <- as.Date(c("2024-06-30", "2024-12-31"))
  result <- tidybrreg:::resolve_snapshot_dates(available, targets)

  expect_equal(nrow(result), 2)
  expect_equal(result$snapshot_date[1], as.Date("2024-01-01"))
  expect_equal(result$snapshot_date[2], as.Date("2024-07-01"))
})

test_that("resolve_snapshot_dates drops periods before earliest snapshot", {
  available <- as.Date(c("2024-07-01", "2025-01-01"))
  targets <- as.Date(c("2024-06-30", "2024-12-31", "2025-12-31"))
  result <- tidybrreg:::resolve_snapshot_dates(available, targets)

  expect_equal(nrow(result), 2)
  expect_equal(result$target_date[1], as.Date("2024-12-31"))
})

test_that("generate_year_targets produces year-end dates", {
  targets <- tidybrreg:::generate_year_targets(as.Date("2023-03-15"), as.Date("2025-09-01"))
  expect_equal(targets, as.Date(c("2023-12-31", "2024-12-31", "2025-12-31")))
})

test_that("brreg_panel produces firm-period tibble from fixtures", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  panel <- brreg_panel(frequency = "year",
                        cols = c("name", "employees", "legal_form"),
                        type = "enheter")

  expect_s3_class(panel, "tbl_df")
  expect_true(all(c("org_nr", "period", "snapshot_date", "name", "employees") %in% names(panel)))
  expect_true(nrow(panel) > 0)

  expect_true("is_entry" %in% names(panel))
  expect_true("is_exit" %in% names(panel))

  periods <- unique(panel$period)
  expect_true(length(periods) >= 1)

  mapping <- attr(panel, "date_mapping")
  expect_s3_class(mapping, "tbl_df")
})

test_that("brreg_panel with label = TRUE translates codes", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  panel <- brreg_panel(frequency = "year",
                        cols = c("legal_form"),
                        type = "enheter",
                        label = TRUE)
  expect_true(any(grepl("company|proprietor", panel$legal_form, ignore.case = TRUE)))
})
