test_that("brreg_events detects entries and exits", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  events <- brreg_events("2024-01-01", "2024-07-01", type = "enheter")
  expect_s3_class(events, "tbl_df")
  expect_true(all(c("org_nr", "event_type", "event_date", "field",
                     "value_from", "value_to") %in% names(events)))

  entries <- events[events$event_type == "entry", ]
  exits <- events[events$event_type == "exit", ]
  expect_true("100000004" %in% entries$org_nr)
  expect_true("100000003" %in% exits$org_nr)
})

test_that("brreg_events detects field changes", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  events <- brreg_events("2024-01-01", "2024-07-01",
                          cols = c("name", "employees", "municipality_code"),
                          type = "enheter")
  changes <- events[events$event_type == "change", ]

  name_changes <- changes[changes$field == "name", ]
  expect_true("100000002" %in% name_changes$org_nr)
  expect_equal(name_changes$value_from[name_changes$org_nr == "100000002"], "Beta AS")
  expect_equal(name_changes$value_to[name_changes$org_nr == "100000002"], "Beta Rebranded AS")

  emp_changes <- changes[changes$field == "employees", ]
  expect_true("100000001" %in% emp_changes$org_nr)

  loc_changes <- changes[changes$field == "municipality_code", ]
  expect_true("100000002" %in% loc_changes$org_nr)
})

test_that("brreg_events returns empty tibble for identical snapshots", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))

  events <- brreg_events("2024-01-01", "2024-01-01", type = "enheter")
  changes <- events[events$event_type %in% c("entry", "exit", "change"), ]
  expect_equal(nrow(changes), 0)
})

test_that("brreg_events errors on missing snapshot", {
  skip_if_not_installed("nanoparquet")
  withr::local_options(brreg.data_dir = test_path("fixtures"))
  expect_error(brreg_events("2020-01-01", "2024-01-01"), "No snapshot")
})
