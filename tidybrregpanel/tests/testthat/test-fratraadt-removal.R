# fratraadt-era tests for functions that moved to tidybrregpanel.

raw_roles <- function(with_fratraadt = FALSE) {
  role1 <- list(
    type = list(kode = "LEDE", beskrivelse = "Styrets leder"),
    person = list(fodselsdato = "1970-01-01", erDoed = FALSE,
                  navn = list(fornavn = "Kari", etternavn = "Nordmann")),
    rekkefolge = 0L
  )
  role2 <- list(
    type = list(kode = "MEDL", beskrivelse = "Styremedlem"),
    person = list(fodselsdato = "1980-02-02", erDoed = FALSE,
                  navn = list(fornavn = "Ola", etternavn = "Hansen")),
    avregistrert = TRUE,
    rekkefolge = 1L
  )
  if (with_fratraadt) role1$fratraadt <- TRUE
  list(rollegrupper = list(list(
    type = list(kode = "STYR", beskrivelse = "Styre"),
    sistEndret = "2026-01-01",
    roller = list(role1, role2)
  )))
}

flatten_roles <- tidybrreg:::flatten_roles

test_that("brreg_board_summary excludes deregistered when resigned absent", {
  roles <- flatten_roles(raw_roles(FALSE), "999888777")
  s <- brreg_board_summary(roles)
  expect_equal(s$board_size, 1L)
  expect_equal(s$n_members, 0L)
})

test_that("brreg_board_summary still excludes resigned when present", {
  roles <- flatten_roles(raw_roles(TRUE), "999888777")
  s <- brreg_board_summary(roles)
  expect_equal(s$board_size, 0L)
})

test_that("diff_roller_state handles old-with vs new-without resigned", {
  old <- flatten_roles(raw_roles(TRUE), "999888777")
  new <- flatten_roles(raw_roles(FALSE), "999888777")
  cl <- diff_roller_state(old, new, timestamp = "t", update_id = 1L)
  expect_false("resigned" %in% cl$field)
  expect_s3_class(cl, "tbl_df")

  entry_only <- diff_roller_state(NULL, new, timestamp = "t", update_id = 1L)
  expect_false("resigned" %in% entry_only$field)
  expect_true(nrow(entry_only) > 0)
})
