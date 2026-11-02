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

# Contract reversed: rename_and_coerce() previously guaranteed every
# field_dict column, materializing absent ones as typed NA. That made a
# field the register had stopped emitting indistinguishable from one
# present and null, which is how a removal like fratraadt goes unseen.
# Emission is now batch-scoped: observed fields only.

test_that("rename_and_coerce emits only observed field_dict columns", {
  dat <- tibble::tibble(organisasjonsnummer = "923609016")
  result <- tidybrreg:::rename_and_coerce(dat)

  expect_equal(names(result), "org_nr")
  absent <- setdiff(field_dict$col_name, "org_nr")
  expect_false(any(absent %in% names(result)))
})

test_that("observed columns are coerced to their declared types", {
  typed <- field_dict[!duplicated(field_dict$col_name), ]
  samples <- list(Date = "1995-02-19", integer = "42",
                  character = "x", logical = "true", numeric = "1.5")
  keep <- typed[typed$type %in% names(samples) &
                  !grepl("\\[\\]|\\.", typed$api_path), ]
  dat <- tibble::as_tibble(stats::setNames(
    lapply(keep$type, function(ty) samples[[ty]]), keep$api_path
  ))
  result <- tidybrreg:::rename_and_coerce(dat)

  for (i in seq_len(nrow(keep))) {
    col <- keep$col_name[i]
    if (!col %in% names(result)) next
    switch(keep$type[i],
      Date      = expect_s3_class(result[[col]], "Date"),
      integer   = expect_type(result[[col]], "integer"),
      numeric   = expect_type(result[[col]], "double"),
      logical   = expect_type(result[[col]], "logical"),
      character = expect_type(result[[col]], "character")
    )
  }
})

# --- Pipeline 1 multi-value field collapse (found via fixtures) ---
# Previously: rename_from_dict() passed length > 1 vectors to
# tibble::as_tibble() which rejected incompatible sizes.
# Fix: collapse to a scalar via collapse_observed(), which joins on
# "\n" so the observed elements can be recovered by splitting.

test_that("rename_from_dict collapses multi-value fields to scalar", {
  flat <- list(
    organisasjonsnummer = "923609016",
    vedtektsfestetFormaal = c("Purpose line 1", "Purpose line 2", "Purpose line 3"),
    aktivitet = c("Activity 1", "Activity 2")
  )
  result <- tidybrreg:::rename_from_dict(flat)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(strsplit(result$purpose, "\n")[[1]],
               c("Purpose line 1", "Purpose line 2", "Purpose line 3"))
  expect_equal(strsplit(result$activity, "\n")[[1]],
               c("Activity 1", "Activity 2"))
})

test_that("rename_from_dict handles single-value fields unchanged", {
  flat <- list(
    organisasjonsnummer = "923609016",
    navn = "EQUINOR ASA"
  )
  result <- tidybrreg:::rename_from_dict(flat)
  expect_equal(result$name, "EQUINOR ASA")
})

test_that("rename_from_dict omits fields the response did not carry", {
  flat <- list(
    organisasjonsnummer = "923609016"
  )
  result <- tidybrreg:::rename_from_dict(flat)
  expect_false("purpose" %in% names(result))
  expect_false("activity" %in% names(result))
  expect_equal(names(result), "org_nr")
})

# --- LOCF max_gap enforcement (Gap 5.1) ---

# --- Parquet backend tiering (audit confirmed, regression guard) ---

# --- Invisible returns on side-effect functions (audit confirmed) ---

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
