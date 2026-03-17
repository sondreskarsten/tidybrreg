# Tests for exported functions that had zero test coverage.
# These were identified during the audit gap analysis.

# --- brreg_survival_data ---

test_that("brreg_survival_data computes duration and event", {
  data <- tibble::tibble(
    org_nr = c("111111111", "222222222", "333333333"),
    founding_date = as.Date(c("2010-01-15", "2015-06-01", "2020-03-01")),
    bankruptcy_date = as.Date(c(NA, "2023-11-30", NA)),
    deletion_date = as.Date(c(NA, NA, NA))
  )
  result <- brreg_survival_data(data, censoring_date = as.Date("2025-01-01"))

  expect_true("entry_date" %in% names(result))
  expect_true("exit_date" %in% names(result))
  expect_true("duration_years" %in% names(result))
  expect_true("event" %in% names(result))

  expect_type(result$event, "integer")
  expect_equal(result$event, c(0L, 1L, 0L))
  expect_true(all(result$duration_years > 0, na.rm = TRUE))
})

test_that("brreg_survival_data uses exit hierarchy correctly", {
  data <- tibble::tibble(
    org_nr = "111111111",
    founding_date = as.Date("2010-01-01"),
    bankruptcy_date = as.Date("2020-06-01"),
    liquidation_date = as.Date("2020-03-01"),
    deletion_date = as.Date("2021-01-01")
  )
  result <- brreg_survival_data(data)
  expect_equal(result$exit_date, as.Date("2020-03-01"))
})

test_that("brreg_survival_data respects entry_var argument", {
  data <- tibble::tibble(
    org_nr = "111111111",
    founding_date = as.Date("2010-01-01"),
    registration_date = as.Date("2010-02-15")
  )
  result <- brreg_survival_data(data, entry_var = "registration_date")
  expect_equal(result$entry_date, as.Date("2010-02-15"))
})

test_that("brreg_survival_data errors on missing entry_var", {
  data <- tibble::tibble(org_nr = "111111111")
  expect_error(brreg_survival_data(data), "founding_date")
})

test_that("brreg_survival_data output is survival::Surv compatible", {
  data <- tibble::tibble(
    org_nr = c("111", "222"),
    founding_date = as.Date(c("2010-01-01", "2015-01-01")),
    bankruptcy_date = as.Date(c(NA, "2020-01-01"))
  )
  result <- brreg_survival_data(data, censoring_date = as.Date("2025-01-01"))
  expect_type(result$event, "integer")
  expect_true(all(result$event %in% c(0L, 1L)))
  expect_type(result$duration_years, "double")
  expect_true(all(result$duration_years > 0, na.rm = TRUE))
})

# --- brreg_board_network ---

test_that("brreg_board_network requires tidygraph", {
  skip_if_not_installed("tidygraph")

  roles <- tibble::tibble(
    org_nr = rep(c("111", "222"), each = 3),
    role_group = "Board of Directors",
    role = "Board member",
    first_name = c("Ola", "Kari", "Per", "Kari", "Anna", "Jon"),
    last_name = c("Hansen", "Olsen", "Berg", "Olsen", "Dahl", "Lie"),
    birth_date = as.Date(c("1970-01-01", "1975-06-15", "1980-03-20",
                            "1975-06-15", "1985-11-10", "1960-04-05")),
    person_id = paste(c("1970-01-01", "1975-06-15", "1980-03-20",
                         "1975-06-15", "1985-11-10", "1960-04-05"),
                       c("Hansen", "Olsen", "Berg", "Olsen", "Dahl", "Lie"),
                       c("Ola", "Kari", "Per", "Kari", "Anna", "Jon"))
  )

  result <- brreg_board_network(roles_data = roles)
  expect_s3_class(result, "tbl_graph")
})

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
