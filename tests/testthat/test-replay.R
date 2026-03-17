test_that("brreg_replay inserts new entities", {
  base <- tibble::tibble(
    org_nr = c("111111111", "222222222"),
    name = c("Firm A", "Firm B"),
    employees = c(10L, 20L)
  )

  updates <- tibble::tibble(
    org_nr = "333333333",
    change_type = "Ny",
    timestamp = as.POSIXct("2025-06-01 10:00:00", tz = "UTC"),
    changes = list(tibble::tibble(
      operation = "add", field = "name", new_value = "Firm C"
    ))
  )

  result <- brreg_replay(base, updates, target_date = "2025-12-31")
  expect_equal(nrow(result), 3)
  expect_true("333333333" %in% result$org_nr)

  info <- attr(result, "replay_info")
  expect_equal(info$n_insert, 1L)
  expect_equal(info$n_update, 0L)
  expect_equal(info$n_delete, 0L)
})

test_that("brreg_replay deletes entities on Sletting", {
  base <- tibble::tibble(
    org_nr = c("111111111", "222222222"),
    name = c("Firm A", "Firm B"),
    employees = c(10L, 20L)
  )

  updates <- tibble::tibble(
    org_nr = "222222222",
    change_type = "Sletting",
    timestamp = as.POSIXct("2025-06-01 10:00:00", tz = "UTC")
  )

  result <- brreg_replay(base, updates, target_date = "2025-12-31")
  expect_equal(nrow(result), 1)
  expect_equal(result$org_nr, "111111111")

  info <- attr(result, "replay_info")
  expect_equal(info$n_delete, 1L)
})

test_that("brreg_replay filters by target_date", {
  base <- tibble::tibble(
    org_nr = "111111111",
    name = "Firm A"
  )

  updates <- tibble::tibble(
    org_nr = c("222222222", "333333333"),
    change_type = c("Ny", "Ny"),
    timestamp = as.POSIXct(c("2025-03-01", "2025-09-01"), tz = "UTC"),
    changes = list(
      tibble::tibble(operation = "add", field = "name", new_value = "Early"),
      tibble::tibble(operation = "add", field = "name", new_value = "Late")
    )
  )

  result <- brreg_replay(base, updates, target_date = "2025-06-01")
  expect_equal(nrow(result), 2)
  expect_false("333333333" %in% result$org_nr)
})

test_that("brreg_replay returns base unchanged when no updates", {
  base <- tibble::tibble(org_nr = "111111111", name = "Firm A")
  updates <- tibble::tibble(
    org_nr = character(), change_type = character(),
    timestamp = as.POSIXct(character())
  )
  result <- brreg_replay(base, updates)
  expect_equal(nrow(result), 1)
  expect_equal(result$org_nr, "111111111")
})

test_that("lookup_patch_field maps known fields via field_dict", {
  valid_cols <- c("org_nr", "name", "employees", "founding_date")
  result <- tidybrreg:::lookup_patch_field("antallAnsatte", valid_cols)
  expect_equal(result, "employees")
})

test_that("lookup_patch_field falls back to snake_case", {
  valid_cols <- c("org_nr", "some_custom_field")
  result <- tidybrreg:::lookup_patch_field("someCustomField", valid_cols)
  expect_equal(result, "some_custom_field")
})

test_that("lookup_patch_field returns NULL for unknown fields", {
  valid_cols <- c("org_nr", "name")
  result <- tidybrreg:::lookup_patch_field("totallyUnknownField", valid_cols)
  expect_null(result)
})
