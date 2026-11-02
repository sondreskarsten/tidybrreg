clear_hist_cache <- function() {
  if (exists("state_historiske_navn", envir = .brregEnv)) {
    rm("state_historiske_navn", envir = .brregEnv)
  }
}

test_that("brreg_historical_names warns and returns empty when no state", {
  withr::local_options(brreg.data_dir = withr::local_tempdir())
  clear_hist_cache()
  expect_message(res <- brreg_historical_names(), "No name-history data")
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c("org_nr", "position", "name", "from_date", "to_date"))
})

test_that("brreg_historical_names reads state and filters by org_nr", {
  skip_if_not(parquet_tier() != "none")
  withr::local_options(brreg.data_dir = withr::local_tempdir())
  clear_hist_cache()
  hist <- tibble::tibble(
    org_nr = c("999888777", "999888777", "111222333"),
    position = c(0L, 1L, 0L),
    name = c("A", "B", "C"),
    from_date = "2020-01-01 00:00:00",
    to_date = "2021-01-01 00:00:00"
  )
  write_state(hist, "historiske_navn")

  all_rows <- brreg_historical_names()
  expect_equal(nrow(all_rows), 3L)

  one <- brreg_historical_names("999888777")
  expect_equal(nrow(one), 2L)
  expect_setequal(one$name, c("A", "B"))
  clear_hist_cache()
})
