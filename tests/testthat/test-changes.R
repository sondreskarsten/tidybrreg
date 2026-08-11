test_that("brreg_changes filters late-arriving events by event date", {
  skip_if(tidybrreg:::parquet_tier() == "none")
  withr::local_options(brreg.data_dir = withr::local_tempdir())

  changes <- tibble::tibble(
    timestamp = c("2026-08-05T23:59:59Z", "2026-08-06T00:00:00Z"),
    org_nr = c("111111111", "222222222"),
    registry = "enheter",
    change_type = "entry",
    field = NA_character_,
    value_from = NA_character_,
    value_to = NA_character_,
    update_id = 1:2
  )
  tidybrreg:::write_changelog(changes, sync_date = as.Date("2026-08-06"))

  result <- brreg_changes(from = as.Date("2026-08-06"))

  expect_equal(result$org_nr, "222222222")
})
