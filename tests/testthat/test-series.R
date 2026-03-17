test_that("brreg_series counts entities when .vars is NULL", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  result <- brreg_series(frequency = "year", type = "enheter")
  expect_s3_class(result, "tbl_df")
  expect_true("period" %in% names(result))
  expect_true("n" %in% names(result))
  expect_true(all(result$n > 0))
})

test_that("brreg_series aggregates with custom .fns", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  result <- brreg_series(
    .vars = "employees",
    .fns = list(avg = function(x) mean(x, na.rm = TRUE),
                total = function(x) sum(x, na.rm = TRUE)),
    frequency = "year",
    type = "enheter"
  )
  expect_s3_class(result, "tbl_df")
  expect_true("employees_avg" %in% names(result))
  expect_true("employees_total" %in% names(result))
})

test_that("brreg_series groups by column", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  result <- brreg_series(by = "legal_form", frequency = "year", type = "enheter")
  expect_true("legal_form" %in% names(result))
  expect_true(length(unique(result$legal_form)) >= 1)
})

test_that("brreg_series attaches brreg_panel_meta attribute", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  result <- brreg_series(by = "legal_form", frequency = "year", type = "enheter")
  meta <- attr(result, "brreg_panel_meta")
  expect_type(meta, "list")
  expect_equal(meta$index, "period")
  expect_equal(meta$frequency, "year")
})
