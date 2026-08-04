# historiskeNavn CDC ingest (BRREG change 2026-06-16/18)
# Op shape observed live 2026-08-04: a rename emits
#   {"op":"replace","path":"/navn","value":"NEW"}
#   {"op":"add","path":"/historiskeNavn/-","value":{"navn":"OLD","fraDato":"...","tilDato":"..."}}

hist_add_patch <- function(navn = "GAMLE NAVN AS",
                            fra = "2024-10-12 14:38:08",
                            til = "2026-07-25 06:00:50") {
  list(
    list(op = "replace", path = "/navn", value = "NYE NAVN AS"),
    list(op = "add", path = "/historiskeNavn/-",
         value = list(navn = navn, fraDato = fra, tilDato = til))
  )
}

test_that("parse_patch flattens historiskeNavn add ops to _-_ fields", {
  parsed <- parse_patch(hist_add_patch())
  hist <- parsed[grepl("^historiskeNavn", parsed$field), ]
  expect_setequal(
    hist$field,
    c("historiskeNavn_-_navn", "historiskeNavn_-_fraDato",
      "historiskeNavn_-_tilDato")
  )
  expect_true(all(hist$operation == "add"))
  expect_equal(hist$new_value[hist$field == "historiskeNavn_-_navn"],
               "GAMLE NAVN AS")
})

test_that("apply_historiske_navn_patches appends with position index", {
  state <- empty_historiske_navn()
  parsed <- parse_patch(hist_add_patch())
  hist <- parsed[grepl("^historiskeNavn", parsed$field), ]

  res <- apply_historiske_navn_patches(state, "999888777", hist,
                                        "2026-07-25T06:00:50Z", 42L)
  expect_equal(nrow(res$state), 1L)
  expect_equal(res$state$org_nr, "999888777")
  expect_equal(res$state$position, 0L)
  expect_equal(res$state$name, "GAMLE NAVN AS")
  expect_equal(res$state$from_date, "2024-10-12 14:38:08")
  expect_equal(res$state$to_date, "2026-07-25 06:00:50")

  expect_equal(nrow(res$changelog), 1L)
  expect_equal(res$changelog$registry, "historiske_navn")
  expect_equal(res$changelog$change_type, "name_history_added")
  expect_equal(res$changelog$field, "GAMLE NAVN AS")
  expect_equal(res$changelog$update_id, 42L)

  parsed2 <- parse_patch(hist_add_patch(navn = "ENDA ELDRE AS",
                                         fra = "2020-01-01 00:00:00",
                                         til = "2024-10-12 14:38:08"))
  hist2 <- parsed2[grepl("^historiskeNavn", parsed2$field), ]
  res2 <- apply_historiske_navn_patches(res$state, "999888777", hist2,
                                         "2026-07-26T00:00:00Z", 43L)
  expect_equal(nrow(res2$state), 2L)
  expect_equal(res2$state$position, c(0L, 1L))
})

test_that("apply_endring_events routes historiskeNavn for underenheter", {
  state <- tibble::tibble(org_nr = "999888777", name = "NYE NAVN AS")
  events <- tibble::tibble(
    org_nr = "999888777",
    timestamp = "2026-07-25T06:00:50Z",
    update_id = 42L,
    change_type = "Endring",
    endringer = list(hist_add_patch())
  )

  res <- apply_endring_events(state, NULL, NULL, events, "underenheter")

  expect_equal(nrow(res$hist_state), 1L)
  expect_equal(res$hist_state$name, "GAMLE NAVN AS")
  expect_true("name_history_added" %in% res$changelog$change_type)
  expect_equal(res$state$name, "NYE NAVN AS")
  expect_false(any(grepl("historiskeNavn", res$changelog$field)))
})

test_that("apply_endring_events routes historiskeNavn for enheter alongside paategninger", {
  state <- tibble::tibble(org_nr = "999888777", name = "NYE NAVN AS")
  paat <- empty_paategninger()
  events <- tibble::tibble(
    org_nr = "999888777",
    timestamp = "2026-07-25T06:00:50Z",
    update_id = 42L,
    change_type = "Endring",
    endringer = list(hist_add_patch())
  )

  res <- apply_endring_events(state, paat, NULL, events, "enheter")
  expect_equal(nrow(res$hist_state), 1L)
  expect_equal(nrow(res$paat_state), 0L)
})

test_that("apply_slett_events removes name history for the deleted org", {
  hist <- tibble::tibble(
    org_nr = c("999888777", "111222333"),
    position = c(0L, 0L),
    name = c("A", "B"),
    from_date = NA_character_, to_date = NA_character_
  )
  state <- tibble::tibble(org_nr = c("999888777", "111222333"))
  slett <- tibble::tibble(
    org_nr = "999888777", timestamp = "t", update_id = 1L,
    change_type = "Sletting"
  )
  res <- apply_slett_events(state, NULL, hist, slett, "underenheter")
  expect_equal(res$hist_state$org_nr, "111222333")
})
