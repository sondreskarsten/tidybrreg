test_that("brreg_data_dir returns valid path", {
  dir <- brreg_data_dir()
  expect_type(dir, "character")
  expect_true(dir.exists(dir))
})

test_that("brreg_snapshots returns empty tibble when no snapshots", {
  withr::local_options(brreg.data_dir = withr::local_tempdir())
  result <- brreg_snapshots("enheter")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true(all(c("snapshot_date", "file_size", "path") %in% names(result)))
})

test_that("brreg_snapshots lists fixture partitions", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))
  result <- brreg_snapshots("enheter")
  expect_equal(nrow(result), 3)
  expect_s3_class(result$snapshot_date, "Date")
  expect_equal(result$snapshot_date, as.Date(c("2024-01-01", "2024-07-01", "2025-01-01")))
})

test_that("brreg_import writes a parquet partition", {
  skip_if_not_installed("nanoparquet")
  tmp <- withr::local_tempdir()
  withr::local_options(brreg.data_dir = tmp)

  csv_path <- withr::local_tempfile(fileext = ".csv")
  df <- tibble::tibble(
    organisasjonsnummer = "999999999",
    navn = "Test",
    `organisasjonsform.kode` = "AS",
    antallAnsatte = "5",
    stiftelsesdato = "2020-01-01",
    konkurs = "FALSE"
  )
  readr::write_csv(df, csv_path)

  path <- brreg_import(csv_path, snapshot_date = "2023-12-31")
  expect_true(file.exists(path))

  snaps <- brreg_snapshots("enheter")
  expect_equal(nrow(snaps), 1)
  expect_equal(snaps$snapshot_date, as.Date("2023-12-31"))
})

test_that("brreg_import is idempotent", {
  skip_if_not_installed("nanoparquet")
  tmp <- withr::local_tempdir()
  withr::local_options(brreg.data_dir = tmp)

  csv_path <- withr::local_tempfile(fileext = ".csv")
  df <- tibble::tibble(organisasjonsnummer = "999999999", navn = "Test")
  readr::write_csv(df, csv_path)

  brreg_import(csv_path, snapshot_date = "2023-12-31")
  # Second call should not error, just skip
  path2 <- brreg_import(csv_path, snapshot_date = "2023-12-31")
  expect_true(file.exists(path2))
})

test_that("brreg_cleanup removes old snapshots by count", {
  skip_if_not_installed("nanoparquet")
  tmp <- withr::local_tempdir()
  withr::local_options(brreg.data_dir = tmp)

  for (d in c("2024-01-01", "2024-06-01", "2024-12-01")) {
    dir.create(file.path(tmp, "enheter", paste0("snapshot_date=", d)),
               recursive = TRUE)
    nanoparquet::write_parquet(
      tibble::tibble(org_nr = "1"),
      file.path(tmp, "enheter", paste0("snapshot_date=", d), "data.parquet")
    )
  }

  expect_equal(nrow(brreg_snapshots("enheter")), 3)
  brreg_cleanup(keep_n = 1, type = "enheter")
  expect_equal(nrow(brreg_snapshots("enheter")), 1)
  expect_equal(brreg_snapshots("enheter")$snapshot_date, as.Date("2024-12-01"))
})

test_that("brreg_open requires arrow", {
  skip_if_not_installed("arrow")
  withr::local_options(brreg.data_dir = test_path("fixtures"))
  ds <- brreg_open("enheter")
  expect_s3_class(ds, "Dataset")
})
