# Bootstrap extraction from the JSON bulk (format = "json").
# Columns are built by tidybrreg:::flatten_cell() serializing the array-of-objects
# to a JSON string, so tests round-trip through the real serializer.

test_that("extract_historiske_navn parses the serialized JSON bulk column", {
  h1 <- data.frame(
    navn = c("STATOIL ASA", "Den norske stats oljeselskap a.s"),
    fraDato = c("2001-05-11 08:32:09", "1995-03-12 16:23:00"),
    tilDato = c("2007-10-01 06:44:33", "2001-05-11 08:32:09")
  )
  h2 <- data.frame(navn = "OLD B", fraDato = "2020-01-01 00:00:00",
                   tilDato = "2021-01-01 00:00:00")
  entities <- tibble::tibble(
    org_nr = c("111111111", "222222222", "333333333"),
    historiske_navn = c(tidybrreg:::flatten_cell(h1), tidybrreg:::flatten_cell(h2), NA_character_)
  )

  res <- extract_historiske_navn(entities)
  expect_equal(nrow(res), 3L)
  expect_named(res, c("org_nr", "position", "name", "from_date", "to_date"))
  one <- res[res$org_nr == "111111111", ]
  expect_equal(one$position, c(0L, 1L))
  expect_equal(one$name[1], "STATOIL ASA")
  expect_equal(one$from_date[2], "1995-03-12 16:23:00")
  expect_false("333333333" %in% res$org_nr)
})

test_that("extract_historiske_navn returns empty on CSV-shaped input", {
  entities <- tibble::tibble(org_nr = "111111111", name = "X")
  res <- extract_historiske_navn(entities)
  expect_equal(nrow(res), 0L)
  expect_named(res, c("org_nr", "position", "name", "from_date", "to_date"))

  all_na <- tibble::tibble(org_nr = "111111111",
                            historiske_navn = NA_character_)
  expect_equal(nrow(extract_historiske_navn(all_na)), 0L)
})

test_that("extract_paategninger parses inline JSON arrays without fetching", {
  p1 <- data.frame(infotype = c("DAGL", "FADR"),
                   tekst = c("Kontaktperson mangler", "Adresse mangler"),
                   innfoertDato = c("2025-05-05", "2025-06-06"))
  entities <- tibble::tibble(
    org_nr = c("111111111", "222222222"),
    annotations = c(tidybrreg:::flatten_cell(p1), NA_character_)
  )
  testthat::local_mocked_bindings(
    fetch_entity_paategninger = function(org_nr) stop("should not fetch")
  )
  res <- extract_paategninger(entities)
  expect_equal(nrow(res), 2L)
  expect_equal(res$org_nr, c("111111111", "111111111"))
  expect_equal(res$position, c(0L, 1L))
  expect_equal(res$infotype, c("DAGL", "FADR"))
  expect_equal(res$innfoert_dato, c("2025-05-05", "2025-06-06"))
})

test_that("extract_paategninger flag path is unchanged for CSV bulk", {
  entities <- tibble::tibble(
    org_nr = c("111111111", "222222222"),
    annotations = c("true", "false")
  )
  testthat::local_mocked_bindings(
    fetch_entity_paategninger = function(org_nr) {
      tibble::tibble(org_nr = org_nr, position = 0L, infotype = "FADR",
                     tekst = "x", innfoert_dato = "2026-01-01")
    }
  )
  res <- extract_paategninger(entities)
  expect_equal(res$org_nr, "111111111")
})
