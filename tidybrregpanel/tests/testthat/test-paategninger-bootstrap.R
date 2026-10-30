test_that("extract_paategninger fetches only flagged entities and builds state", {
  entities <- tibble::tibble(
    org_nr = c("111111111", "222222222", "333333333"),
    annotations = c("true", "false", "true")
  )
  testthat::local_mocked_bindings(
    fetch_entity_paategninger = function(org_nr) {
      tibble::tibble(org_nr = org_nr, position = 0L, infotype = "FADR",
                     tekst = "x", innfoert_dato = "2026-01-01")
    }
  )
  res <- extract_paategninger(entities)
  expect_setequal(unique(res$org_nr), c("111111111", "333333333"))
  expect_equal(nrow(res), 2)
  expect_named(res, c("org_nr", "position", "infotype", "tekst", "innfoert_dato"))
})

test_that("extract_paategninger returns empty when no flags are true", {
  entities <- tibble::tibble(org_nr = c("111111111", "222222222"),
                             annotations = c("false", "false"))
  testthat::local_mocked_bindings(
    fetch_entity_paategninger = function(org_nr) stop("should not fetch")
  )
  res <- extract_paategninger(entities)
  expect_equal(nrow(res), 0)
  expect_named(res, c("org_nr", "position", "infotype", "tekst", "innfoert_dato"))
})

test_that("extract_paategninger returns empty when the flag column is missing", {
  res <- extract_paategninger(tibble::tibble(org_nr = "111111111", navn = "x"))
  expect_equal(nrow(res), 0)
})

test_that("extract_paategninger also accepts a column literally named paategninger", {
  testthat::local_mocked_bindings(
    fetch_entity_paategninger = function(org_nr) {
      tibble::tibble(org_nr = org_nr, position = 0L, infotype = "KONT",
                     tekst = "y", innfoert_dato = "2026-02-01")
    }
  )
  res <- extract_paategninger(tibble::tibble(org_nr = "111111111", paategninger = "true"))
  expect_equal(nrow(res), 1)
  expect_equal(res$infotype, "KONT")
})
