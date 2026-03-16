# These tests hit the live brreg API and are skipped on CRAN
# and when no internet is available

skip_if_offline <- function() {
  skip_on_cran()
  tryCatch({
    httr2::request("https://data.brreg.no") |>
      httr2::req_method("HEAD") |>
      httr2::req_timeout(10) |>
      httr2::req_perform()
  }, error = function(e) skip("brreg API not reachable"))
}

# Wrap API calls so transient network errors skip instead of fail
safely <- function(expr) {
  tryCatch(expr, error = function(e) {
    if (grepl("curl|connection|timeout|schannel|SSL|receive", e$message, ignore.case = TRUE)) {
      skip(paste("Network error:", e$message))
    }
    stop(e)
  })
}

test_that("brreg_entity returns correct structure", {
  skip_if_offline()
  eq <- safely(brreg_entity("923609016"))
  expect_s3_class(eq, "tbl_df")
  expect_equal(nrow(eq), 1)
  expect_equal(eq$org_nr, "923609016")
  expect_equal(eq$name, "EQUINOR ASA")
  expect_equal(eq$legal_form, "ASA")
  expect_true(is.integer(eq$employees))
  expect_s3_class(eq$founding_date, "Date")
  expect_true(is.logical(eq$bankrupt))
})

test_that("brreg_entity type = label works", {
  skip_if_offline()
  eq <- safely(brreg_entity("923609016", type = "label"))
  expect_match(eq$legal_form, "company", ignore.case = TRUE)
})

test_that("brreg_entity rejects invalid org_nr", {
  expect_error(brreg_entity("123456789"), "Invalid")
})

test_that("brreg_entity handles 404", {
  skip_if_offline()
  expect_error(safely(brreg_entity("999999999")), "not found")
})

test_that("brreg_entity passes through unknown API fields", {
  skip_if_offline()
  eq <- safely(brreg_entity("923609016"))
  expect_gt(ncol(eq), nrow(field_dict))
})

test_that("brreg_search returns results", {
  skip_if_offline()
  s <- safely(brreg_search(name = "Equinor", max_results = 5))
  expect_s3_class(s, "tbl_df")
  expect_gt(nrow(s), 0)
  expect_true("org_nr" %in% names(s))
  expect_false(is.null(attr(s, "total_matches")))
})

test_that("brreg_search filters work", {
  skip_if_offline()
  s <- safely(brreg_search(legal_form = "AS", municipality_code = "0301",
                     min_employees = 1000, max_results = 5))
  expect_gt(nrow(s), 0)
  expect_true(all(s$legal_form == "AS"))
})

test_that("brreg_search returns empty tibble for no matches", {
  skip_if_offline()
  s <- safely(brreg_search(name = "ZZZZNOTEXIST999QQQQQ", max_results = 5))
  expect_equal(nrow(s), 0)
})

test_that("brreg_roles returns correct structure", {
  skip_if_offline()
  roles <- safely(brreg_roles("923609016"))
  expect_s3_class(roles, "tbl_df")
  expect_gt(nrow(roles), 0)
  expect_true(all(c("org_nr", "role_group", "role", "role_code",
                     "first_name", "last_name", "person_id") %in% names(roles)))
  expect_true(any(grepl("Board", roles$role_group)))
  expect_true(any(grepl("Chair|Member|CEO", roles$role)))
  expect_s3_class(roles$birth_date, "Date")
})

test_that("brreg_board_summary computes correctly", {
  skip_if_offline()
  roles <- safely(brreg_roles("923609016"))
  bs <- brreg_board_summary(roles)
  expect_equal(nrow(bs), 1)
  expect_gt(bs$board_size, 0)
  expect_true(is.logical(bs$has_ceo))
  expect_true(is.logical(bs$has_auditor))
})

test_that("brreg_updates returns results", {
  skip_if_offline()
  u <- safely(brreg_updates(since = Sys.Date() - 2, size = 10))
  expect_s3_class(u, "tbl_df")
  expect_gt(nrow(u), 0)
  expect_true(all(c("update_id", "org_nr", "change_type", "timestamp") %in% names(u)))
  expect_s3_class(u$timestamp, "POSIXct")
})

test_that("brreg_updates include_changes works", {
  skip_if_offline()
  u <- safely(brreg_updates(since = Sys.Date() - 2, size = 3, include_changes = TRUE))
  expect_true("changes" %in% names(u))
  if (nrow(u) > 0 && !is.null(u$changes[[1]])) {
    expect_s3_class(u$changes[[1]], "tbl_df")
  }
})

test_that("get_brreg_dic fetches NACE codes", {
  skip_if_offline()
  d <- safely(get_brreg_dic("nace"))
  expect_s3_class(d, "tbl_df")
  expect_gt(nrow(d), 1500)
  expect_true("06.100" %in% d$code)
})
