test_that("as_brreg_tsibble converts series output", {
  skip_if_not_installed("tsibble")

  dat <- tibble::tibble(
    period = c("2024", "2025"),
    legal_form = c("AS", "AS"),
    n = c(100L, 110L)
  )
  attr(dat, "brreg_panel_meta") <- list(
    index = "period", key = "legal_form", frequency = "year"
  )

  result <- as_brreg_tsibble(dat)
  expect_s3_class(result, "tbl_ts")
})

test_that("as_brreg_tsibble infers key from brreg_panel_meta", {
  skip_if_not_installed("tsibble")

  dat <- tibble::tibble(
    period = c("2024", "2025"),
    n = c(100L, 110L)
  )
  attr(dat, "brreg_panel_meta") <- list(
    index = "period", key = character(), frequency = "year"
  )

  result <- as_brreg_tsibble(dat)
  expect_s3_class(result, "tbl_ts")
})

test_that("as_brreg_tsibble converts period strings to Date", {
  skip_if_not_installed("tsibble")

  dat <- tibble::tibble(
    period = c("2024", "2025"),
    value = c(1, 2)
  )
  attr(dat, "brreg_panel_meta") <- list(
    index = "period", key = character(), frequency = "year"
  )

  result <- as_brreg_tsibble(dat)
  expect_s3_class(result$period, "Date")
})

test_that("as_brreg_tsibble uses snapshot_date when present", {
  skip_if_not_installed("tsibble")

  dat <- tibble::tibble(
    org_nr = c("111", "222"),
    snapshot_date = as.Date(c("2024-01-01", "2024-07-01")),
    value = c(1, 2)
  )

  result <- as_brreg_tsibble(dat, key = "org_nr")
  expect_s3_class(result, "tbl_ts")
})
