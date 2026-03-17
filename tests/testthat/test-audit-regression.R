# Regression tests for bugs found and fixed during gold-standard audit.
# Each test prevents regression to the pre-fix behavior.

# --- Parse failure tracking (Gap 2.3) ---
# Previously: suppressWarnings(as.integer()) silently produced NA.
# Fix: failures tracked in brreg_parse_problems attribute.

test_that("rename_and_coerce tracks integer parse failures", {
  dat <- tibble::tibble(
    organisasjonsnummer = c("923609016", "984851006"),
    antallAnsatte = c("21408", "not_a_number")
  )
  result <- suppressWarnings(tidybrreg:::rename_and_coerce(dat))
  problems <- attr(result, "brreg_parse_problems")

  expect_false(is.null(problems))
  expect_s3_class(problems, "tbl_df")
  expect_equal(nrow(problems), 1)
  expect_equal(problems$column, "employees")
  expect_equal(problems$expected, "integer")
  expect_equal(problems$actual, "not_a_number")
})

test_that("rename_and_coerce emits cli warning on parse failures", {
  dat <- tibble::tibble(
    organisasjonsnummer = "923609016",
    antallAnsatte = "bad"
  )
  expect_warning(tidybrreg:::rename_and_coerce(dat), "parse failure")
})

test_that("rename_and_coerce has no problems attribute when all parses succeed", {
  dat <- tibble::tibble(
    organisasjonsnummer = "923609016",
    antallAnsatte = "100"
  )
  result <- tidybrreg:::rename_and_coerce(dat)
  expect_null(attr(result, "brreg_parse_problems"))
})

# --- Schema guarantee (Gap 3.1, confirmed in db333a1) ---
# Previously: columns absent from all entities silently disappeared.
# Fix: all 49 field_dict columns present as typed NA.

test_that("rename_and_coerce guarantees all 49 field_dict columns", {
  dat <- tibble::tibble(organisasjonsnummer = "923609016")
  result <- tidybrreg:::rename_and_coerce(dat)

  for (i in seq_len(nrow(field_dict))) {
    col <- field_dict$col_name[i]
    expect_true(col %in% names(result),
      info = paste("Missing field_dict column:", col))
  }
  expect_equal(length(intersect(field_dict$col_name, names(result))),
               nrow(field_dict))
})

test_that("guaranteed columns have correct types", {
  dat <- tibble::tibble(organisasjonsnummer = "923609016")
  result <- tidybrreg:::rename_and_coerce(dat)

  date_cols <- field_dict$col_name[field_dict$type == "Date"]
  int_cols <- field_dict$col_name[field_dict$type == "integer"]
  chr_cols <- field_dict$col_name[field_dict$type == "character"]

  for (col in date_cols) {
    expect_s3_class(result[[col]], "Date")
  }
  for (col in int_cols) {
    expect_type(result[[col]], "integer")
  }
  for (col in chr_cols) {
    expect_type(result[[col]], "character")
  }
})

# --- Pipeline 1 multi-value field collapse (found via fixtures) ---
# Previously: rename_from_dict() passed length > 1 vectors to
# tibble::as_tibble() which rejected incompatible sizes.
# Fix: collapse with paste("; ").

test_that("rename_from_dict collapses multi-value fields to scalar", {
  flat <- list(
    organisasjonsnummer = "923609016",
    vedtektsfestetFormaal = c("Purpose line 1", "Purpose line 2", "Purpose line 3"),
    aktivitet = c("Activity 1", "Activity 2")
  )
  result <- tidybrreg:::rename_from_dict(flat)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_true(grepl("; ", result$purpose))
  expect_true(grepl("; ", result$activity))
})

test_that("rename_from_dict handles single-value fields unchanged", {
  flat <- list(
    organisasjonsnummer = "923609016",
    navn = "EQUINOR ASA"
  )
  result <- tidybrreg:::rename_from_dict(flat)
  expect_equal(result$name, "EQUINOR ASA")
})

test_that("rename_from_dict fills missing fields with typed NA", {
  flat <- list(
    organisasjonsnummer = "923609016"
  )
  result <- tidybrreg:::rename_from_dict(flat)
  expect_true(is.na(result$purpose))
  expect_true(is.na(result$activity))
  expect_type(result$purpose, "character")
  expect_type(result$activity, "character")
})

# --- LOCF max_gap enforcement (Gap 5.1) ---

test_that("resolve_snapshot_dates LOCF works without max_gap", {
  available <- as.Date(c("2024-01-01", "2024-07-01"))
  targets <- as.Date(c("2024-06-30", "2024-12-31", "2025-12-31"))
  result <- tidybrreg:::resolve_snapshot_dates(available, targets)

  expect_equal(result$snapshot_date[result$target_date == as.Date("2025-12-31")],
               as.Date("2024-07-01"))
})

# --- Parquet backend tiering (audit confirmed, regression guard) ---

test_that("parquet_tier returns a valid tier", {
  tier <- tidybrreg:::parquet_tier()
  expect_true(tier %in% c("arrow", "nanoparquet", "none"))
})

test_that("check_parquet_available uses cli error with package suggestions", {
  skip_if(tidybrreg:::parquet_tier() != "none")
  expect_error(tidybrreg:::check_parquet_available(), "parquet backend")
})

# --- Invisible returns on side-effect functions (audit confirmed) ---

test_that("brreg_data_dir returns a character path", {
  result <- brreg_data_dir()
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})

# --- compact() removes NULLs (utility regression) ---

test_that("compact removes NULL elements", {
  result <- tidybrreg:::compact(list(a = 1, b = NULL, c = "x", d = NULL))
  expect_equal(names(result), c("a", "c"))
  expect_equal(result$a, 1)
  expect_equal(result$c, "x")
})

test_that("compact returns empty list from all-NULL input", {
  result <- tidybrreg:::compact(list(a = NULL, b = NULL))
  expect_equal(length(result), 0)
})
