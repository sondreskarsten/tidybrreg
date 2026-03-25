test_that("is_cloud_path detects schemes correctly", {
  expect_true(tidybrreg:::is_cloud_path("gs://bucket/path"))
  expect_true(tidybrreg:::is_cloud_path("s3://bucket/path"))
  expect_false(tidybrreg:::is_cloud_path("/local/path"))
  expect_false(tidybrreg:::is_cloud_path("~/path"))
  expect_false(tidybrreg:::is_cloud_path("relative/path"))
})

test_that("check_cloud_arrow is no-op for local paths", {
  expect_null(tidybrreg:::check_cloud_arrow("/local/path"))
})

test_that("ensure_dir is no-op for cloud paths", {
  expect_invisible(tidybrreg:::ensure_dir("gs://bucket/path"))
  expect_invisible(tidybrreg:::ensure_dir("s3://bucket/path"))
})

test_that("local: state write/read round-trip", {
  tmp <- withr::local_tempdir("brreg_test_")
  withr::local_options(brreg.data_dir = tmp)

  df <- tibble::tibble(org_nr = c("123", "456"), name = c("A", "B"))
  tidybrreg:::write_state(df, "test_type")
  expect_true(tidybrreg:::has_state("test_type"))

  result <- tidybrreg:::read_state("test_type", use_cache = FALSE)
  expect_equal(nrow(result), 2L)
  expect_equal(result$org_nr, c("123", "456"))
})

test_that("local: cursor stored as parquet", {
  tmp <- withr::local_tempdir("brreg_test_")
  withr::local_options(brreg.data_dir = tmp)

  cursor <- list(enheter_id = 42L, underenheter_id = 99L, roller_id = 7L)
  tidybrreg:::write_cursor(cursor)

  parquet_path <- file.path(tidybrreg:::state_dir(), "sync_cursor.parquet")
  expect_true(file.exists(parquet_path))

  result <- tidybrreg:::read_cursor()
  expect_equal(result$enheter_id, 42L)
  expect_equal(result$underenheter_id, 99L)
  expect_equal(result$roller_id, 7L)
  expect_false(is.na(result$last_sync))
})

test_that("local: JSON cursor migrates to parquet", {
  tmp <- withr::local_tempdir("brreg_test_")
  withr::local_options(brreg.data_dir = tmp)

  sd <- tidybrreg:::state_dir()
  json_path <- file.path(sd, "sync_cursor.json")
  jsonlite::write_json(
    list(enheter_id = 100L, underenheter_id = 200L, roller_id = 300L,
         last_sync = "2026-03-01T12:00:00"),
    json_path, auto_unbox = TRUE
  )

  migrated <- tidybrreg:::read_cursor()
  expect_equal(migrated$enheter_id, 100L)
  expect_equal(migrated$underenheter_id, 200L)
  expect_false(file.exists(json_path))
  expect_true(file.exists(file.path(sd, "sync_cursor.parquet")))
})

test_that("local: changelog write/read round-trip", {
  tmp <- withr::local_tempdir("brreg_test_")
  withr::local_options(brreg.data_dir = tmp)

  changes <- tibble::tibble(
    timestamp = "2026-03-25T10:00:00", org_nr = "123456789",
    registry = "enheter", change_type = "change",
    field = "name", value_from = "Old", value_to = "New", update_id = 1L
  )
  tidybrreg:::write_changelog(changes, sync_date = "2026-03-25")

  result <- tidybrreg:::read_changelog(from = "2026-03-25", to = "2026-03-25")
  expect_equal(nrow(result), 1L)
  expect_equal(result$org_nr, "123456789")
})

test_that("local: defaults when no cursor exists", {
  tmp <- withr::local_tempdir("brreg_empty_")
  withr::local_options(brreg.data_dir = tmp)
  fresh <- tidybrreg:::read_cursor()
  expect_equal(fresh$enheter_id, 0L)
  expect_equal(fresh$underenheter_id, 0L)
  expect_equal(fresh$roller_id, 0L)
  expect_true(is.na(fresh$last_sync))
})

test_that("local: brreg_sync_status runs clean", {
  tmp <- withr::local_tempdir("brreg_test_")
  withr::local_options(brreg.data_dir = tmp)
  result <- tidybrreg::brreg_sync_status()
  expect_type(result, "list")
  expect_named(result, c("cursor", "state", "changelog_partitions"))
  expect_false(result$state$enheter$exists)
})

test_that("local: cloud_file_exists delegates to file.exists", {
  f <- withr::local_tempfile(fileext = ".parquet")
  arrow::write_parquet(tibble::tibble(x = 1), f)
  expect_true(tidybrreg:::cloud_file_exists(f))
  expect_false(tidybrreg:::cloud_file_exists(paste0(f, ".nope")))
})

test_that("local: cloud_file_info returns size and mtime", {
  f <- withr::local_tempfile(fileext = ".parquet")
  arrow::write_parquet(tibble::tibble(x = 1:100), f)
  info <- tidybrreg:::cloud_file_info(f)
  expect_true(info$exists)
  expect_gt(info$size, 0)
  expect_s3_class(info$mtime, "POSIXct")

  missing <- tidybrreg:::cloud_file_info(paste0(f, ".nope"))
  expect_false(missing$exists)
})


# === GCS integration tests ===

skip_if_no_gcs <- function() {
  creds <- Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
  if (nchar(creds) == 0 || !file.exists(creds)) {
    skip("No GCS credentials available")
  }
  if (!arrow::arrow_with_gcs()) {
    skip("Arrow GCS support not compiled")
  }
}

test_that("GCS: state round-trip", {
  skip_on_cran()
  skip_if_no_gcs()

  gcs_base <- "gs://sondreskarsten-d7d14_cloudbuild/tidybrreg-ci-test"
  withr::local_options(brreg.data_dir = gcs_base)
  withr::defer({
    gcs <- arrow::GcsFileSystem$create()
    sel <- arrow::FileSelector$create(sub("^gs://", "", gcs_base), recursive = TRUE)
    entries <- tryCatch(gcs$GetFileInfo(sel), error = \(e) list())
    for (e in entries) if (e$type == 2L) gcs$DeleteFile(e$path)
  })

  df <- tibble::tibble(org_nr = "999000111", name = "GCS Test AS")
  tidybrreg:::write_state(df, "enheter")
  expect_true(tidybrreg:::has_state("enheter"))
  result <- tidybrreg:::read_state("enheter", use_cache = FALSE)
  expect_equal(result$name, "GCS Test AS")
})

test_that("GCS: cursor round-trip", {
  skip_on_cran()
  skip_if_no_gcs()

  gcs_base <- "gs://sondreskarsten-d7d14_cloudbuild/tidybrreg-ci-cursor"
  withr::local_options(brreg.data_dir = gcs_base)
  withr::defer({
    gcs <- arrow::GcsFileSystem$create()
    sel <- arrow::FileSelector$create(sub("^gs://", "", gcs_base), recursive = TRUE)
    entries <- tryCatch(gcs$GetFileInfo(sel), error = \(e) list())
    for (e in entries) if (e$type == 2L) gcs$DeleteFile(e$path)
  })

  tidybrreg:::write_cursor(list(enheter_id = 555L, underenheter_id = 666L, roller_id = 777L))
  r <- tidybrreg:::read_cursor()
  expect_equal(r$enheter_id, 555L)
  expect_equal(r$roller_id, 777L)
})

test_that("GCS: cloud_file_exists detects missing files", {
  skip_on_cran()
  skip_if_no_gcs()
  expect_false(tidybrreg:::cloud_file_exists(
    "gs://sondreskarsten-d7d14_cloudbuild/tidybrreg-ci-test/nosuchfile.parquet"
  ))
})
