test_that("brreg_manifest returns empty tibble when no manifest exists", {
  tmp <- withr::local_tempdir()
  withr::local_options(brreg.data_dir = tmp)

  result <- brreg_manifest()
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true(all(c("id", "type", "snapshot_date", "endpoint", "format",
                     "download_timestamp", "last_modified", "etag",
                     "file_hash", "record_count", "raw_path",
                     "parquet_path",
                     "cdc_bridge_first_update_id") %in% names(result)))
})

test_that("write_manifest_entry creates manifest and appends entries", {
  tmp <- withr::local_tempdir()
  withr::local_options(brreg.data_dir = tmp)

  entry1 <- list(
    id = "enheter_2024-01-01", type = "enheter",
    snapshot_date = "2024-01-01", endpoint = "https://example.com/1",
    format = "csv", download_timestamp = "2024-01-01T10:00:00Z",
    last_modified = "Mon, 01 Jan 2024 06:00:00 GMT",
    etag = "\"abc123\"", file_hash = "xxhash1",
    record_count = 100, raw_path = "/tmp/a.csv.gz",
    parquet_path = "/tmp/data.parquet"
  )
  tidybrreg:::write_manifest_entry(entry1)

  manifest_file <- file.path(tmp, "manifest.json")
  expect_true(file.exists(manifest_file))

  result <- brreg_manifest()
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "enheter_2024-01-01")
  expect_equal(result$record_count, 100L)

  entry2 <- list(
    id = "enheter_2024-07-01", type = "enheter",
    snapshot_date = "2024-07-01", endpoint = "https://example.com/2",
    format = "json", download_timestamp = "2024-07-01T10:00:00Z",
    last_modified = NA_character_, etag = NA_character_,
    file_hash = "xxhash2", record_count = 200,
    raw_path = "/tmp/b.json.gz", parquet_path = "/tmp/data2.parquet"
  )
  tidybrreg:::write_manifest_entry(entry2)

  result2 <- brreg_manifest()
  expect_equal(nrow(result2), 2)
  expect_equal(result2$format, c("csv", "json"))
})

test_that("build_manifest_entry constructs correct entry without response", {
  tmp <- withr::local_tempdir()
  raw <- file.path(tmp, "test.csv.gz")
  writeLines("test", raw)

  entry <- tidybrreg:::build_manifest_entry(
    type = "enheter", snapshot_date = as.Date("2025-01-01"),
    endpoint = "https://data.brreg.no/test", format = "csv",
    resp = NULL, raw_path = raw, parquet_path = "/tmp/out.parquet",
    record_count = 500
  )

  expect_equal(entry$type, "enheter")
  expect_equal(entry$snapshot_date, "2025-01-01")
  expect_equal(entry$record_count, 500)
  expect_true(is.na(entry$last_modified))
  expect_true(is.na(entry$etag))
  expect_true(!is.na(entry$file_hash))
})

test_that("build_manifest_entry stores cdc_bridge_first_update_id", {
  tmp <- withr::local_tempdir()
  raw <- file.path(tmp, "test.csv.gz")
  writeLines("test", raw)

  entry <- tidybrreg:::build_manifest_entry(
    type = "enheter", snapshot_date = as.Date("2025-01-01"),
    endpoint = "https://data.brreg.no/test", format = "csv",
    raw_path = raw, record_count = 500,
    cdc_bridge_first_update_id = 12345678L
  )

  expect_equal(entry$cdc_bridge_first_update_id, 12345678L)
})

test_that("manifest round-trips cdc_bridge_first_update_id", {
  tmp <- withr::local_tempdir()
  withr::local_options(brreg.data_dir = tmp)

  entry_with <- list(
    id = "enheter_2025-01-01", type = "enheter",
    snapshot_date = "2025-01-01", endpoint = "https://example.com",
    format = "csv", download_timestamp = "2025-01-01T10:00:00Z",
    last_modified = NA_character_, etag = NA_character_,
    file_hash = NA_character_, record_count = 100,
    raw_path = NA_character_, parquet_path = NA_character_,
    cdc_bridge_first_update_id = 99887766
  )
  tidybrreg:::write_manifest_entry(entry_with)

  entry_without <- list(
    id = "enheter_2025-07-01", type = "enheter",
    snapshot_date = "2025-07-01", endpoint = "https://example.com",
    format = "json", download_timestamp = "2025-07-01T10:00:00Z",
    last_modified = NA_character_, etag = NA_character_,
    file_hash = NA_character_, record_count = 200,
    raw_path = NA_character_, parquet_path = NA_character_
  )
  tidybrreg:::write_manifest_entry(entry_without)

  result <- brreg_manifest()
  expect_equal(nrow(result), 2)
  expect_equal(result$cdc_bridge_first_update_id[1], 99887766L)
  expect_true(is.na(result$cdc_bridge_first_update_id[2]))
})
