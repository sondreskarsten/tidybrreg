# Contract tests for the retained core: conditions, typed empties,
# deletion modelling, result window, completeness metadata, time
# handling, coercion parity, HAL stripping, labelling, and load purity.
# Every HTTP interaction is mocked through helper-mock.R.

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------

test_that("the namespace exports exactly the 16 core functions", {
  expected <- c(
    "brreg_entity", "brreg_search", "brreg_underenheter", "brreg_children",
    "brreg_roles", "brreg_roles_legal", "brreg_konsern", "brreg_signatur",
    "brreg_prokura", "brreg_regnskap", "brreg_updates", "brreg_update_fields",
    "brreg_download", "brreg_label", "get_brreg_dic", "brreg_validate"
  )
  ns <- readLines(system.file("NAMESPACE", package = "tidybrreg"))
  if (length(ns) == 0) ns <- readLines(testthat::test_path("..", "..", "NAMESPACE"))
  actual <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))
  expect_setequal(actual, expected)
  expect_length(actual, 16L)
})

# ---------------------------------------------------------------------------
# brreg_entity: deletion, validation, status mapping
# ---------------------------------------------------------------------------

test_that("brreg_entity flags a live entity as not deleted", {
  local_brreg_responses(stub_resp(200L, entity_body()))
  res <- brreg_entity("923609016")
  expect_false(res$deleted)
  expect_equal(res$registry, "enheter")
  expect_equal(res$legal_form, "ASA")
  expect_s3_class(res$founding_date, "Date")
  expect_type(res$employees, "integer")
})

test_that("brreg_entity models HTTP 200 SlettetEnhet as deleted", {
  body <- entity_body(respons_klasse = "SlettetEnhet", slettedato = "2026-02-01")
  local_brreg_responses(stub_resp(200L, body))
  expect_warning(res <- brreg_entity("923609016"), class = "tidybrreg_warning_deleted")
  expect_true(res$deleted)
  expect_equal(res$deletion_date, as.Date("2026-02-01"))
  expect_equal(res$response_class, "SlettetEnhet")
  expect_equal(res$name, "EQUINOR ASA")
})

test_that("brreg_entity models HTTP 410 the same way and keeps fields", {
  body <- list(organisasjonsnummer = "923609016", slettedato = "2026-02-01",
               respons_klasse = "SlettetEnhet", navn = "GONE AS")
  local_brreg_responses(list(stub_resp(410L, body), stub_resp(410L, body)))
  w <- tryCatch(brreg_entity("923609016"), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_deleted")
  expect_equal(w$deletion_date, as.Date("2026-02-01"))
  res <- suppressWarnings(brreg_entity("923609016"))
  expect_true(res$deleted)
  expect_equal(res$name, "GONE AS")
  expect_equal(res$registry, "enheter")
  expect_equal(res$deletion_date, as.Date("2026-02-01"))
})

test_that("brreg_entity rejects vectors and invalid numbers with a typed error", {
  e <- tryCatch(brreg_entity(c("923609016", "984851006")), error = function(e) e)
  expect_s3_class(e, "tidybrreg_error_invalid_org_nr")
  e <- tryCatch(brreg_entity("123456789"), error = function(e) e)
  expect_s3_class(e, "tidybrreg_error_invalid_org_nr")
  expect_equal(e$org_nr, "123456789")
})

test_that("brreg_entity signals not_found on 404 and http on 500", {
  local_brreg_responses(list(stub_resp(404L), stub_resp(404L)))
  e <- tryCatch(brreg_entity("923609016"), error = function(e) e)
  expect_s3_class(e, "tidybrreg_error_not_found")
  expect_equal(e$status, 404L)

  local_brreg_responses(stub_resp(500L, list(error = "boom")))
  e <- tryCatch(brreg_entity("923609016"), error = function(e) e)
  expect_s3_class(e, "tidybrreg_error_http")
  expect_equal(e$status, 500L)
  expect_equal(e$messages, "boom")
})

test_that("brreg_entity falls through to underenheter on 404", {
  local_brreg_responses(list(stub_resp(404L), stub_resp(200L, entity_body("974760843"))))
  res <- brreg_entity("974760843")
  expect_equal(res$registry, "underenheter")
})

test_that("nested HAL links never reach entity output", {
  local_brreg_responses(stub_resp(200L, entity_body()))
  res <- brreg_entity("923609016")
  expect_false(any(grepl("links", names(res))))
})

# ---------------------------------------------------------------------------
# brreg_search: typed empty, filters, result window, completeness
# ---------------------------------------------------------------------------

test_that("brreg_search returns a typed empty tibble on no matches", {
  local_brreg_responses(stub_resp(200L, list(page = list(totalElements = 0L))))
  res <- brreg_search(name = "zzz")
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_named(res, c("org_nr", "name", "legal_form"))
  expect_type(res$org_nr, "character")
  expect_equal(attr(res, "total_matches"), 0L)
  expect_true(attr(res, "complete"))
})

test_that("brreg_search aborts on unsupported filters", {
  e <- tryCatch(brreg_search(bankrupt = TRUE, registry = "underenheter"),
                error = function(e) e)
  expect_s3_class(e, "tidybrreg_error_invalid_filter")
  expect_equal(e$filter, "bankrupt")
  expect_error(brreg_search(max_results = 0), class = "tidybrreg_error_invalid_filter")
})

test_that("brreg_search aborts before returning a partial population", {
  items <- list(entity_body("923609016"))
  local_brreg_responses(stub_resp(200L, search_body(items, total = 57954L, has_next = TRUE)))
  e <- tryCatch(brreg_search(municipality_code = "4601", max_results = 20000),
                error = function(e) e)
  expect_s3_class(e, "tidybrreg_error_result_window")
  expect_equal(e$total_matches, 57954L)
  expect_equal(e$retrieval_limit, 10000L)
  expect_equal(e$filters$municipality_code, "4601")
  expect_equal(e$endpoint, "enheter")
})

test_that("brreg_search within the window reports truncation explicitly", {
  items <- list(entity_body("923609016"), entity_body("984851006"))
  local_brreg_responses(stub_resp(200L, search_body(items, total = 57954L, has_next = TRUE)))
  w <- tryCatch(brreg_search(municipality_code = "4601", max_results = 2),
                warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_truncated")
  expect_equal(w$returned, 2L)
  expect_equal(w$total_matches, 57954L)
  local_brreg_responses(stub_resp(200L, search_body(items, total = 57954L, has_next = TRUE)))
  res <- suppressWarnings(brreg_search(municipality_code = "4601", max_results = 2))
  expect_equal(nrow(res), 2L)
  expect_false(attr(res, "complete"))
  expect_equal(attr(res, "total_matches"), 57954L)
})

test_that("brreg_search paginates with an exclusive window check", {
  page1 <- stub_resp(200L, search_body(list(entity_body("923609016")), total = 2L, has_next = TRUE))
  page2 <- stub_resp(200L, search_body(list(entity_body("984851006")), total = 2L))
  q <- local_brreg_responses(list(page1, page2))
  res <- brreg_search(name = "x", max_results = 1000)
  expect_equal(nrow(res), 2L)
  expect_true(attr(res, "complete"))
  expect_length(q$requests, 2L)
  expect_match(q$requests[[2]]$url, "page=1")
})

test_that("brreg_search aborts on a first-page failure and warns on later ones", {
  local_brreg_responses(stub_resp(503L))
  e <- tryCatch(brreg_search(name = "x"), error = function(e) e)
  expect_s3_class(e, "tidybrreg_error_http")

  page1 <- stub_resp(200L, search_body(list(entity_body("923609016")), total = 2L, has_next = TRUE))
  local_brreg_responses(list(page1, stub_resp(503L)))
  w <- tryCatch(brreg_search(name = "x", max_results = 1000), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_partial")
  expect_equal(w$pages_fetched, 1L)
  local_brreg_responses(list(page1, stub_resp(503L)))
  res <- suppressWarnings(brreg_search(name = "x", max_results = 1000))
  expect_equal(nrow(res), 1L)
  expect_false(attr(res, "complete"))
})

test_that("brreg_underenheter and brreg_children validate the org number", {
  expect_error(brreg_underenheter("123"), class = "tidybrreg_error_invalid_org_nr")
  expect_error(brreg_children("123"), class = "tidybrreg_error_invalid_org_nr")
})

# ---------------------------------------------------------------------------
# Satellite endpoints: status contract and typed empties
# ---------------------------------------------------------------------------

test_that("satellite endpoints return typed empties on 404 without warning", {
  fns <- list(brreg_roles, brreg_roles_legal, brreg_konsern, brreg_signatur, brreg_prokura)
  empties <- list(tidybrreg:::empty_roles(), tidybrreg:::empty_roles_legal(),
                  tidybrreg:::empty_konsern(), tidybrreg:::empty_signatur(),
                  tidybrreg:::empty_signatur())
  for (i in seq_along(fns)) {
    local_brreg_responses(stub_resp(404L))
    expect_no_warning(res <- fns[[i]]("923609016"))
    expect_equal(nrow(res), 0L)
    expect_named(res, names(empties[[i]]))
    expect_equal(attr(res, "http_status"), 404L)
  }
})

test_that("satellite endpoints warn on 410 and abort on 500", {
  local_brreg_responses(stub_resp(410L, list(slettedato = "2026-02-01")))
  w <- tryCatch(brreg_roles("923609016"), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_deleted")
  local_brreg_responses(stub_resp(410L, list(slettedato = "2026-02-01")))
  res <- suppressWarnings(brreg_roles("923609016"))
  expect_equal(attr(res, "http_status"), 410L)
  expect_equal(attr(res, "deletion_date"), as.Date("2026-02-01"))

  local_brreg_responses(stub_resp(500L))
  expect_error(brreg_konsern("923609016"), class = "tidybrreg_error_http")
})

test_that("brreg_roles with no rollegrupper returns the typed empty", {
  local_brreg_responses(stub_resp(200L, list(organisasjonsnummer = "923609016",
                                             rollegrupper = list())))
  res <- brreg_roles("923609016")
  expect_equal(nrow(res), 0L)
  expect_s3_class(res$birth_date, "Date")
  expect_type(res$deregistered, "logical")
  expect_null(attr(res, "http_status"))
})

test_that("konsern relation dates parse in both BRREG renderings", {
  raw <- list(organisasjonsnummer = "923609016", navn = "MOR", nivaa = 0L,
              children = list(
                list(organisasjonsnummer = "810034882", navn = "A", nivaa = 1L,
                     knytningsform = list(kode = "KDAT"), dato = "24.06.2026"),
                list(organisasjonsnummer = "974760843", navn = "B", nivaa = 1L,
                     knytningsform = list(kode = "KDAT"), dato = "2026-06-24")
              ))
  res <- tidybrreg:::flatten_konsern(raw, "923609016")
  expect_equal(res$relation_date[2:3], as.Date(c("2026-06-24", "2026-06-24")))
  expect_equal(res$link_form[1], "KKKK")
})

test_that("signatur birth dates join to roles birth dates", {
  raw <- list(
    enhet = list(navn = "X AS"),
    status = list(regelStatus = list(kode = "RF")),
    signeringsKombinasjon = list(kombinasjon = list(list(
      kombinasjonsId = 1L, kode = "STYR", tekstforklaring = "Styret i fellesskap",
      personRolleKombinasjon = list(list(navn = "Kari Nordmann", fodselsdato = "01.01.1970",
                                         rolle = list(kode = "LEDE")))
    )))
  )
  res <- tidybrreg:::flatten_signatur(raw, "923609016", "signature")
  expect_equal(res$birth_date, as.Date("1970-01-01"))
  expect_equal(res$role, "Chair of the Board")
  expect_type(res$combination_id, "character")
})

# ---------------------------------------------------------------------------
# Update feeds: time handling, completeness, unknown members, patches
# ---------------------------------------------------------------------------

test_that("format_since keeps POSIXct precision and renders UTC", {
  withr::local_timezone("America/New_York")
  expect_equal(tidybrreg:::format_since(as.Date("2026-03-01")), "2026-03-01T00:00:00.000Z")
  inst <- as.POSIXct("2026-03-01 14:00:00", tz = "Europe/Oslo")
  expect_equal(tidybrreg:::format_since(inst), "2026-03-01T13:00:00.000Z")
  expect_equal(tidybrreg:::format_since("2026-03-01T14:00:00Z"), "2026-03-01T14:00:00.000Z")
  expect_equal(tidybrreg:::format_since("2026-03-01"), "2026-03-01T00:00:00.000Z")
  expect_error(tidybrreg:::format_since("yesterday"), class = "tidybrreg_error_invalid_since")
})

test_that("instants are parsed as UTC whatever the session time zone", {
  for (tz in c("UTC", "Pacific/Auckland", "America/Los_Angeles")) {
    withr::local_timezone(tz)
    x <- tidybrreg:::parse_brreg_instant(c("2026-03-15T10:30:00.000Z", "2026-03-15T10:30:00",
                                           "2026-03-15"))
    expect_equal(attr(x, "tzone"), "UTC")
    expect_equal(format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
                 c("2026-03-15 10:30:00", "2026-03-15 10:30:00", "2026-03-15 00:00:00"))
  }
})

test_that("HTTP dates parse in a non-English locale", {
  withr::local_locale(c(LC_TIME = "C"))
  x <- tidybrreg:::parse_http_date("Wed, 21 Oct 2026 07:28:00 GMT")
  expect_equal(format(x, "%Y-%m-%d %H:%M", tz = "UTC"), "2026-10-21 07:28")
  expect_true(is.na(tidybrreg:::parse_http_date(NULL)))
})

test_that("brreg_updates sends since as a UTC instant and returns UTC timestamps", {
  withr::local_timezone("America/New_York")
  q <- local_brreg_responses(stub_resp(200L, update_body(list(update_event(1L)))))
  res <- brreg_updates(since = as.POSIXct("2026-03-01 14:00:00", tz = "Europe/Oslo"))
  expect_match(q$requests[[1]]$url, "dato=2026-03-01T13%3A00%3A00.000Z", fixed = TRUE)
  expect_equal(attr(res$timestamp, "tzone"), "UTC")
  expect_equal(format(res$timestamp, "%H:%M", tz = "UTC"), "10:30")
  expect_true(attr(res, "complete"))
  expect_equal(attr(res, "cursor"), 1L)
})

test_that("brreg_updates returns a typed empty on an empty feed", {
  local_brreg_responses(stub_resp(200L, list()))
  res <- brreg_updates()
  expect_equal(nrow(res), 0L)
  expect_named(res, c("update_id", "org_nr", "change_type", "timestamp"))
  expect_s3_class(res$timestamp, "POSIXct")
  local_brreg_responses(stub_resp(200L, list()))
  res <- brreg_updates(include_changes = TRUE)
  expect_true("changes" %in% names(res))
})

test_that("brreg_updates paginates on the exclusive cursor and flags truncation", {
  page1 <- stub_resp(200L, update_body(list(update_event(1L), update_event(2L))))
  page2 <- stub_resp(200L, update_body(list(update_event(3L))))
  q <- local_brreg_responses(list(page1, page2))
  res <- brreg_updates(size = 2, max_pages = 5)
  expect_equal(res$update_id, 1:3)
  expect_match(q$requests[[2]]$url, "oppdateringsid=3", fixed = TRUE)
  expect_true(attr(res, "complete"))

  local_brreg_responses(list(page1))
  w <- tryCatch(brreg_updates(size = 2, max_pages = 1), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_truncated")
  local_brreg_responses(list(page1))
  res <- suppressWarnings(brreg_updates(size = 2, max_pages = 1))
  expect_false(attr(res, "complete"))
  expect_equal(attr(res, "cursor"), 2L)
})

test_that("brreg_updates aborts on first-page failure and warns on later failure", {
  local_brreg_responses(stub_resp(500L))
  expect_error(brreg_updates(), class = "tidybrreg_error_http")
  page1 <- stub_resp(200L, update_body(list(update_event(1L), update_event(2L))))
  local_brreg_responses(list(page1, stub_resp(503L)))
  w <- tryCatch(brreg_updates(size = 2, max_pages = 3), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_partial")
  expect_equal(w$pages_fetched, 1L)
})

test_that("unknown update members pass through with a typed warning", {
  ev <- update_event(1L, nyttFelt = "x", nested = list(a = 1, b = 2))
  local_brreg_responses(stub_resp(200L, update_body(list(ev))))
  w <- tryCatch(brreg_updates(), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_unknown_member")
  expect_setequal(w$members, c("nyttFelt", "nested"))
  local_brreg_responses(stub_resp(200L, update_body(list(ev))))
  res <- suppressWarnings(brreg_updates())
  expect_equal(res$nytt_felt, "x")
  expect_match(res$nested, "\"a\":1")
  expect_setequal(attr(res, "unknown_members"), c("nyttFelt", "nested"))
})

test_that("roller feed honours max_pages and rejects include_changes", {
  expect_error(brreg_updates(type = "roller", include_changes = TRUE),
               class = "tidybrreg_error_invalid_filter")
  ev <- function(id) list(specversion = "1.0", id = as.character(id),
                          type = "no.brreg.enhetsregisteret.rolle.oppdatert",
                          time = "2026-03-15T10:30:00.000Z",
                          data = list(organisasjonsnummer = "923609016"))
  q <- local_brreg_responses(list(stub_resp(200L, list(ev(1), ev(2))), stub_resp(200L, list(ev(3)))))
  res <- brreg_updates(type = "roller", size = 2, max_pages = 5)
  expect_equal(res$update_id, 1:3)
  expect_equal(res$change_type, rep("oppdatert", 3))
  expect_match(q$requests[[1]]$url, "afterTime=", fixed = TRUE)
  expect_match(q$requests[[2]]$url, "afterId=2", fixed = TRUE)
  expect_true(attr(res, "complete"))
})

test_that("parse_patch keeps the raw pointer and flattens any depth", {
  endringer <- list(
    list(op = "replace", path = "/antallAnsatte", value = 21500L),
    list(op = "add", path = "/forretningsadresse",
         value = list(adresse = list("Gate 1", "Inng. 2"),
                      sub = list(deep = list(leaf = "v")))),
    list(op = "move", from = "/postadresse/poststed", path = "/forretningsadresse/poststed",
         value = "OSLO"),
    list(op = "remove", path = "/hjemmeside")
  )
  res <- tidybrreg:::parse_patch(endringer)
  expect_named(res, c("operation", "field", "path", "new_value"))
  expect_true("/forretningsadresse/sub/deep/leaf" %in% res$path)
  expect_equal(res$field[res$path == "/forretningsadresse/sub/deep/leaf"],
               "forretningsadresse_sub_deep_leaf")
  expect_equal(res$new_value[res$path == "/forretningsadresse/adresse/1"], "Inng. 2")
  mv <- res[res$operation == "remove", ]
  expect_true(all(c("/postadresse/poststed", "/hjemmeside") %in% mv$path))
  expect_true(all(is.na(mv$new_value)))
})

test_that("brreg_update_fields emits one row per leaf and synthetic NA rows", {
  ev1 <- update_event(1L, endringer = list(
    list(op = "replace", path = "/antallAnsatte", value = 5L),
    list(op = "add", path = "/x", value = list(a = list(b = list(c = "d"))))
  ))
  ev2 <- update_event(2L, type = "Ny")
  local_brreg_responses(stub_resp(200L, update_body(list(ev1, ev2))))
  res <- brreg_update_fields()
  expect_named(res, c("update_id", "org_nr", "change_type", "timestamp",
                      "operation", "field", "path", "new_value"))
  expect_equal(nrow(res), 3L)
  expect_true(is.na(res$operation[res$update_id == 2L]))
  expect_equal(res$path[which(res$field == "x_a_b_c")], "/x/a/b/c")
  expect_equal(attr(res$timestamp, "tzone"), "UTC")
  local_brreg_responses(stub_resp(200L, list()))
  expect_equal(nrow(brreg_update_fields()), 0L)
})

test_that("flatten_page_patches agrees with the changes list-column", {
  ev <- update_event(7L, endringer = list(
    list(op = "add", path = "/k", value = list(list(x = 1), list(x = 2)))
  ))
  flat <- tidybrreg:::flatten_page_patches(list(ev))
  nested <- tidybrreg:::parse_updates_page(list(ev), include_changes = TRUE)$changes[[1]]
  expect_equal(flat$path, nested$path)
  expect_equal(flat$new_value, nested$new_value)
})

# ---------------------------------------------------------------------------
# Coercion, parse problems, dictionary collisions, HAL stripping (bulk path)
# ---------------------------------------------------------------------------

test_that("numeric dictionary columns coerce identically on bulk and live paths", {
  bulk <- tibble::tibble(organisasjonsnummer = "923609016",
                         kapital.belop = "5976872600.00",
                         kapital.antallAksjer = "2556807512")
  res <- tidybrreg:::rename_and_coerce(bulk)
  expect_type(res$capital_amount, "double")
  expect_equal(res$capital_amount, 5976872600)
  expect_equal(res$capital_shares, 2556807512)
  live <- tidybrreg:::parse_entity(list(organisasjonsnummer = "923609016",
                                        kapital = list(belop = 5976872600, antallAksjer = 2556807512)))
  expect_equal(class(live$capital_amount), class(res$capital_amount))
  expect_equal(live$capital_amount, res$capital_amount)
})

test_that("every dictionary type coerces and reports failures on both paths", {
  bulk <- tibble::tibble(
    organisasjonsnummer = c("1", "2"), stiftelsesdato = c("2020-01-01", "nope"),
    antallAnsatte = c("5", "five"), konkurs = c("true", "maybe"),
    kapital.belop = c("1.5", "x")
  )
  w <- tryCatch(tidybrreg:::rename_and_coerce(bulk), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_parse")
  expect_equal(w$n, 4L)
  res <- suppressWarnings(tidybrreg:::rename_and_coerce(bulk))
  probs <- attr(res, "brreg_parse_problems")
  expect_setequal(probs$column, c("founding_date", "employees", "bankrupt", "capital_amount"))
  expect_true(all(probs$row == 2L))
  expect_s3_class(res$founding_date, "Date")
  expect_true(res$bankrupt[1])
  live <- suppressWarnings(tidybrreg:::parse_entity(list(organisasjonsnummer = "1",
                                                         antallAnsatte = "five")))
  expect_equal(attr(live, "brreg_parse_problems")$column, "employees")
})

test_that("more than twenty parse failures do not abort the parse", {
  bulk <- tibble::tibble(organisasjonsnummer = as.character(1:30),
                         antallAnsatte = rep("bad", 30))
  res <- suppressWarnings(tidybrreg:::rename_and_coerce(bulk))
  probs <- attr(res, "brreg_parse_problems")
  expect_equal(nrow(probs), 20L)
  expect_equal(probs$n_failed[1], 30L)
  expect_equal(probs$row, 1:20)
  expect_equal(probs$actual, rep("bad", 20))
})

test_that("HAL link paths are stripped at any depth on the bulk path", {
  bulk <- tibble::tibble(organisasjonsnummer = "1", `organisasjonsform._links.self.href` = "u",
                         `organisasjonsform.links` = "u", links = "u", navn = "A")
  res <- tidybrreg:::rename_and_coerce(bulk)
  expect_named(res, c("org_nr", "name"))
})

test_that("duplicate dictionary spellings and snake collisions lose nothing", {
  flat <- list(organisasjonsnummer = "1",
               registreringsdatoEnhetsregisteret = "2020-01-01",
               registreringsdatoIEnhetsregisteret = "2021-01-01",
               fooBar = "a", foo.bar = "b")
  res <- tidybrreg:::rename_from_dict(flat)
  expect_equal(res$registration_date, "2020-01-01")
  expect_equal(res$registreringsdato_ienhetsregisteret, "2021-01-01")
  typed <- tidybrreg:::coerce_types(res)
  expect_equal(typed$registreringsdato_ienhetsregisteret, as.Date("2021-01-01"))
  expect_null(attr(typed, "brreg_dict_types"))
  expect_true(all(c("foo_bar", "foo_bar_1") %in% names(res)))
  bulk <- tibble::tibble(organisasjonsnummer = "1",
                         registreringsdatoEnhetsregisteret = "2020-01-01",
                         registreringsdatoIEnhetsregisteret = "2021-01-01")
  res <- tidybrreg:::rename_and_coerce(bulk)
  expect_equal(res$registration_date, as.Date("2020-01-01"))
  expect_equal(res$registreringsdato_ienhetsregisteret, as.Date("2021-01-01"))
})

# ---------------------------------------------------------------------------
# brreg_download argument contract
# ---------------------------------------------------------------------------

test_that("brreg_download validates refresh, cache and type_output", {
  expect_error(brreg_download(refresh = "always"), class = "tidybrreg_error_invalid_filter")
  expect_error(brreg_download(cache = "yes"), class = "tidybrreg_error_invalid_filter")
  expect_error(brreg_download(type_output = "arrow"), "should be one of")
  expect_false("arrow" %in% eval(formals(brreg_download)$type_output))
})

test_that("cache_is_current only trusts matching validators", {
  meta_file <- withr::local_tempfile(fileext = ".json")
  expect_false(tidybrreg:::cache_is_current("https://x", meta_file))
  tidybrreg:::write_download_meta(list(
    url = "https://x", etag = "\"abc\"",
    last_modified = as.POSIXct("2026-10-01 00:00:00", tz = "UTC"),
    downloaded_at = as.POSIXct("2026-10-02 00:00:00", tz = "UTC"), path = "p"
  ), meta_file)
  head_resp <- function(headers) {
    testthat::local_mocked_bindings(
      req_perform = function(req, ...) stub_resp(200L, headers = headers),
      resp_header = function(resp, header, default = NULL) resp$headers[[header]] %||% default,
      .package = "httr2", .env = parent.frame()
    )
  }
  head_resp(list(ETag = "\"abc\""))
  expect_true(tidybrreg:::cache_is_current("https://x", meta_file))
  head_resp(list(ETag = "\"def\""))
  expect_false(tidybrreg:::cache_is_current("https://x", meta_file))
  head_resp(list())
  expect_false(tidybrreg:::cache_is_current("https://x", meta_file))
  head_resp(list(`Last-Modified` = "Thu, 01 Oct 2026 00:00:00 GMT"))
  expect_true(tidybrreg:::cache_is_current("https://x", meta_file))
})

# ---------------------------------------------------------------------------
# Labels and dictionaries
# ---------------------------------------------------------------------------

test_that("bundled dictionaries carry source and vintage and need no network", {
  d <- get_brreg_dic("nace", source = "bundled")
  expect_named(d, c("code", "name", "level"))
  expect_equal(attr(d, "source"), "bundled")
  expect_equal(attr(d, "vintage"), as.Date("2026-06-16"))
  expect_true("06.100" %in% d$code)
  expect_error(get_brreg_dic("nace", lang = "no", source = "bundled"),
               class = "tidybrreg_error_no_bundled_dictionary")
})

test_that("the offline option routes auto lookups to the bundled dictionary", {
  withr::local_options(list(tidybrreg.offline = TRUE))
  d <- get_brreg_dic("sector", refresh = TRUE)
  expect_equal(attr(d, "source"), "bundled")
})

test_that("labels honour the language and are idempotent", {
  expect_equal(brreg_label(c("AS", "ENK"), dic = "legal_form", lang = "no"),
               c("Aksjeselskap", "Enkeltpersonforetak"))
  expect_equal(brreg_label("LEDE", dic = "role", lang = "no"), "Styrets leder")
  expect_equal(brreg_label("STYR", dic = "role_group", lang = "no"), "Styre")
  once <- brreg_label(c("AS", "ASA", "ZZZ"), dic = "legal_form")
  expect_identical(brreg_label(once, dic = "legal_form"), once)
  expect_null(names(once))
  expect_equal(once[3], "ZZZ")
})

test_that("brreg_label on a data frame leaves no attributes behind and keeps those given", {
  df <- tibble::tibble(legal_form = c("AS", "ASA"), nace_1 = c("06.100", "64.190"),
                       employees = 1:2)
  attr(df, "total_matches") <- 2L
  res <- brreg_label(df, code = "legal_form")
  expect_null(attributes(res$legal_form))
  expect_equal(attr(res, "total_matches"), 2L)
  expect_equal(names(res)[1:2], c("legal_form_code", "legal_form"))
  expect_identical(brreg_label(res), res)
  expect_equal(res$employees, 1:2)
  expect_match(res$nace_1[1], "petroleum", ignore.case = TRUE)
})

test_that("brreg_label falls back to bundled data with a typed warning", {
  withr::local_options(list(tidybrreg.offline = FALSE))
  testthat::local_mocked_bindings(
    fetch_klass = function(...) stop("no route to host"),
    .package = "tidybrreg"
  )
  w <- tryCatch(get_brreg_dic("nace", refresh = TRUE), warning = function(w) w)
  expect_s3_class(w, "tidybrreg_warning_bundled_fallback")
  expect_equal(w$vintage, as.Date("2026-06-16"))
  expect_error(get_brreg_dic("nace", lang = "no", refresh = TRUE), "no route to host")
})

# ---------------------------------------------------------------------------
# Loading is side-effect free
# ---------------------------------------------------------------------------

test_that("loading and attaching creates no files and prints nothing", {
  skip_if_not_installed("callr")
  home <- withr::local_tempdir()
  pkg_path <- if (nzchar(system.file(package = "tidybrreg"))) system.file(package = "tidybrreg") else NA
  src_path <- normalizePath(testthat::test_path("..", ".."), mustWork = FALSE)
  out <- callr::r(function(home, pkg_path, src_path) {
    Sys.setenv(HOME = home, R_USER_DATA_DIR = file.path(home, "data"),
               R_USER_CACHE_DIR = file.path(home, "cache"),
               XDG_DATA_HOME = file.path(home, "xdg"), XDG_CACHE_HOME = file.path(home, "xdgc"))
    msgs <- character()
    withCallingHandlers({
      if (requireNamespace("tidybrreg", quietly = TRUE)) {
        loadNamespace("tidybrreg")
        library(tidybrreg)
      } else {
        pkgload::load_all(src_path, quiet = TRUE)
      }
      tidybrreg::brreg_validate("923609016")
      nrow(tidybrreg::field_dict)
      tidybrreg::get_brreg_dic("nace", source = "bundled")
    }, message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") },
       packageStartupMessage = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") })
    list(files = list.files(home, recursive = TRUE, all.files = TRUE), msgs = msgs)
  }, args = list(home = home, pkg_path = pkg_path, src_path = src_path))
  expect_length(out$files, 0L)
  expect_length(out$msgs, 0L)
})
