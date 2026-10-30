# Tests for exported functions that had zero test coverage.
# These were identified during the audit gap analysis.

# --- brreg_download structure (offline check) ---

test_that("brreg_download validates type argument", {
  expect_error(brreg_download(type = "invalid"), "should be one of")
})

test_that("brreg_download validates format argument", {
  expect_error(brreg_download(format = "invalid"), "should be one of")
})

test_that("brreg_download validates type_output argument", {
  expect_error(brreg_download(type_output = "invalid"), "should be one of")
})
