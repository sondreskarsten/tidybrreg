# fratraadt removed by BRREG 2026-06-16 from the roller REST endpoints,
# juridiskeroller, and the totalbestand bulk. A column missing on a day
# must not be fabricated; code must handle it when present (old data).

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

test_that("flatten_roles omits resigned when no role carries fratraadt", {
  res <- flatten_roles(raw_roles(FALSE), "999888777")
  expect_false("resigned" %in% names(res))
  expect_true("deregistered" %in% names(res))
  expect_equal(nrow(res), 2L)
})

test_that("flatten_roles keeps resigned with old-era absent-means-FALSE", {
  res <- flatten_roles(raw_roles(TRUE), "999888777")
  expect_true("resigned" %in% names(res))
  expect_equal(res$resigned, c(TRUE, FALSE))
})

test_that("flatten_roles_bulk_fast mirrors both eras", {
  new_era <- list(c(list(organisasjonsnummer = "999888777"),
                    raw_roles(FALSE)))
  res <- flatten_roles_bulk_fast(new_era)
  expect_false("resigned" %in% names(res))

  old_era <- list(c(list(organisasjonsnummer = "999888777"),
                    raw_roles(TRUE)))
  res_old <- flatten_roles_bulk_fast(old_era)
  expect_equal(res_old$resigned, c(TRUE, FALSE))
})

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

test_that("juridiskeroller flattener drops resigned when fratraadt absent", {
  body <- list(enheter = list(list(
    organisasjonsnummer = "111222333", navn = "MOR AS",
    roller = list(list(type = list(kode = "DTPR"), ansvarsandel = "22%",
                       avregistrert = FALSE))
  )))
  testthat::local_mocked_bindings(
    brreg_req = function(...) structure(list(), class = "httr2_request")
  )
  testthat::local_mocked_bindings(
    req_error = function(req, ...) req,
    req_perform = function(req) structure(list(), class = "stub_resp"),
    resp_status = function(resp) 200L,
    resp_body_json = function(resp, ...) body,
    .package = "httr2"
  )
  res <- brreg_roles_legal("999888777")
  expect_false("resigned" %in% names(res))
  expect_equal(res$target_org_nr, "111222333")
})
