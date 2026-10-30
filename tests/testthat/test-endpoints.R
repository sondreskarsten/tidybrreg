# inst/extdata/endpoints.json is the machine-readable contract that
# non-R consumers (tidybrregmcp::mcp_manifest(), the Node MCP server)
# implement. These tests hold it to the functions: the request each
# export builds must match the spec's path and query mapping.

pkg_file <- function(...) {
  path <- system.file(..., package = "tidybrreg")
  if (!nzchar(path)) path <- testthat::test_path("..", "..", "inst", ...)
  path
}

spec <- jsonlite::fromJSON(pkg_file("extdata", "endpoints.json"), simplifyVector = FALSE)

requested <- function(q) vapply(q$requests, function(r) r$url, character(1))

expect_path <- function(url, service, path) {
  base <- spec$services[[service]]
  expect_match(url, paste0("^", gsub("([.?])", "\\\\\\1", paste0(base, path))), perl = TRUE)
}

test_that("every export has an endpoint entry and vice versa", {
  exports <- sub("^export\\((.*)\\)$", "\\1",
                 grep("^export\\(", readLines(system.file("NAMESPACE", package = "tidybrreg")), value = TRUE))
  expect_setequal(names(spec$functions), exports)
})

test_that("brreg_entity requests the routes in auto order", {
  q <- local_brreg_responses(list(stub_resp(404L), stub_resp(200L, entity_body("974760843"))))
  brreg_entity("974760843")
  urls <- requested(q)
  routes <- spec$functions$brreg_entity$routes
  expect_path(urls[1], "enhetsregisteret", sub("\\{org_nr\\}", "974760843", routes[[1]]$path))
  expect_path(urls[2], "enhetsregisteret", sub("\\{org_nr\\}", "974760843", routes[[2]]$path))
  expect_equal(spec$functions$brreg_entity$auto_order, list("enheter", "underenheter"))
})

test_that("brreg_search maps every filter to the documented query parameter", {
  s <- spec$functions$brreg_search
  q <- local_brreg_responses(stub_resp(200L, list(page = list(totalElements = 0L))))
  brreg_search(name = "x", legal_form = "AS", nace_code = "06.100", min_employees = 1,
               max_employees = 9, parent_org_nr = "923609016", municipality_code = "0301",
               bankrupt = TRUE)
  url <- requested(q)[1]
  expect_path(url, "enhetsregisteret", s$routes[[1]]$path)
  for (arg in c("name", "legal_form", "nace_code", "min_employees", "max_employees", "parent_org_nr")) {
    expect_match(url, paste0("[?&]", s$query[[arg]], "="), info = arg)
  }
  expect_match(url, paste0("[?&]", s$query$municipality_code$enheter, "=0301"))
  expect_match(url, paste0("[?&]", s$query$bankrupt$enheter, "=true"))
  expect_match(url, paste0("[?&]", s$pagination$size_param, "=", s$pagination$page_size, "\\b"))
  expect_match(url, paste0("[?&]", s$pagination$page_param, "=0\\b"))

  q <- local_brreg_responses(stub_resp(200L, list(page = list(totalElements = 0L))))
  brreg_search(municipality_code = "0301", registry = "underenheter")
  url <- requested(q)[1]
  expect_path(url, "enhetsregisteret", s$routes[[2]]$path)
  expect_match(url, paste0("[?&]", s$query$municipality_code$underenheter, "=0301"), fixed = FALSE)
  expect_null(s$query$bankrupt$underenheter)
  expect_equal(s$pagination$retrieval_limit, 10000L)
})

test_that("the wrappers delegate to brreg_search as the spec says", {
  for (fn in c("brreg_underenheter", "brreg_children")) {
    d <- spec$functions[[fn]]
    expect_equal(d$delegates_to, "brreg_search")
    q <- local_brreg_responses(stub_resp(200L, list(page = list(totalElements = 0L))))
    get(fn)("923609016")
    url <- requested(q)[1]
    route <- Filter(function(r) r$registry == d$fixed$registry, spec$functions$brreg_search$routes)[[1]]
    expect_path(url, "enhetsregisteret", route$path)
    expect_match(url, paste0("[?&]", spec$functions$brreg_search$query[[d$maps$org_nr]], "=923609016"))
  }
})

test_that("satellite endpoints request their single route", {
  sats <- list(brreg_roles = brreg_roles, brreg_roles_legal = brreg_roles_legal,
               brreg_konsern = brreg_konsern, brreg_signatur = brreg_signatur,
               brreg_prokura = brreg_prokura, brreg_regnskap = brreg_regnskap)
  for (nm in names(sats)) {
    d <- spec$functions[[nm]]
    expect_equal(d$kind, "satellite", info = nm)
    q <- local_brreg_responses(stub_resp(404L))
    res <- sats[[nm]]("923609016")
    expect_path(requested(q)[1], d$service, sub("\\{org_nr\\}", "923609016", d$routes[[1]]$path))
    expect_setequal(names(res), unlist(d$result$empty))
    expect_equal(attr(res, "http_status"), 404L)
  }
})

test_that("brreg_regnskap maps its query and publishes the field map it applies", {
  d <- spec$functions$brreg_regnskap
  q <- local_brreg_responses(stub_resp(200L, list()))
  brreg_regnskap("923609016", year = 2025, account_type = "KONSERN")
  url <- requested(q)[1]
  expect_path(url, d$service, sub("\\{org_nr\\}", "923609016", d$routes[[1]]$path))
  expect_match(url, paste0("[?&]", utils::URLencode(d$query$year, reserved = TRUE), "=2025\\b"))
  expect_match(url, paste0("[?&]", d$query$account_type, "=KONSERN\\b"))
  published <- dplyr::bind_rows(lapply(d$fields, tibble::as_tibble))
  expect_equal(published, tidybrreg:::regnskap_dict)
  expect_equal(dplyr::bind_rows(lapply(d$groups, tibble::as_tibble)), tidybrreg:::regnskap_groups)
  expect_equal(unlist(d$statements), tidybrreg:::regnskap_statements)
  expect_equal(d$identities$tolerance, tidybrreg:::regnskap_tolerance)
  rules <- lapply(d$identities$rules, \(r) list(name = r$name, lhs = r$lhs,
    plus = as.character(unlist(r$plus)), minus = as.character(unlist(r$minus)),
    optional = as.character(unlist(r$optional))))
  expect_equal(rules, tidybrreg:::regnskap_identities)
  expect_equal(unlist(d$result$empty), names(tidybrreg:::empty_regnskap()))
  expect_equal(unlist(d$result$items_columns), names(tidybrreg:::empty_items()))
  mapped <- vapply(d$fields, \(f) f$col_name, character(1))
  used <- unique(unlist(lapply(d$identities$rules, \(r) c(r$lhs, r$plus, r$minus))))
  expect_true(all(used %in% mapped))
})

test_that("the tidy rule in the spec is the rule the flatteners apply", {
  expect_true(all(c("string_arrays", "object_arrays", "empty_arrays") %in% names(spec$tidy)))
  expect_type(tidybrreg:::empty_regnskap()$inconsistencies, "list")
  expect_type(tidybrreg:::empty_regnskap()$items, "list")
  expect_setequal(unlist(spec$tidy$nested_results$brreg_regnskap), c("items", "inconsistencies"))
  lines <- tidybrreg:::collapse_observed(list("a", "b"))
  expect_equal(strsplit(lines, "\n")[[1]], c("a", "b"))
  nested <- tidybrreg:::collapse_observed(list(list(x = 1), list(x = 2)))
  expect_s3_class(nested, "tbl_df")
  expect_false("empty" %in% names(tidybrreg:::flatten_json(list(empty = list()))))
})

test_that("update feeds use the documented cursors", {
  d <- spec$functions$brreg_updates
  page1 <- stub_resp(200L, update_body(list(update_event(1L), update_event(2L))))
  page2 <- stub_resp(200L, update_body(list(update_event(3L))))
  q <- local_brreg_responses(list(page1, page2))
  brreg_updates(since = "2026-03-01", size = 2, max_pages = 5)
  urls <- requested(q)
  expect_path(urls[1], "enhetsregisteret", d$routes[[1]]$path)
  expect_match(urls[1], "[?&]dato=2026-03-01T00%3A00%3A00.000Z")
  expect_match(urls[2], "[?&]oppdateringsid=3\\b")
  expect_match(urls[1], paste0("[?&]", d$pagination$hal$size_param, "=2\\b"))

  q <- local_brreg_responses(stub_resp(200L, update_body(list(), type = "underenheter")))
  brreg_updates(type = "underenheter")
  expect_path(requested(q)[1], "enhetsregisteret", d$routes[[2]]$path)

  ev <- function(id) list(specversion = "1.0", id = as.character(id), type = "no.brreg.x.oppdatert",
                          time = "2026-03-15T10:30:00.000Z", data = list(organisasjonsnummer = "923609016"))
  q <- local_brreg_responses(list(stub_resp(200L, list(ev(1), ev(2))), stub_resp(200L, list())))
  brreg_updates(type = "roller", size = 2, max_pages = 3)
  urls <- requested(q)
  expect_path(urls[1], "enhetsregisteret", d$routes[[3]]$path)
  expect_match(urls[1], "[?&]afterTime=")
  expect_match(urls[2], "[?&]afterId=2\\b")

  q <- local_brreg_responses(stub_resp(200L, update_body(list())))
  brreg_update_fields()
  expect_match(requested(q)[1], paste0("[?&]", d$include_changes$param, "=", d$include_changes$value))
})

test_that("bulk routes and dictionary routes match the spec", {
  d <- spec$functions$brreg_download
  for (r in d$routes) {
    expect_equal(tidybrreg:::bulk_url(r$type, r$format),
                 paste0(spec$services$enhetsregisteret, r$path))
  }
  expect_equal(unlist(d$output_modes), eval(formals(brreg_download)$type_output))
  k <- spec$functions$get_brreg_dic
  for (r in k$routes) {
    id <- switch(r$dictname, nace = 6L, sector = 39L)
    req <- tidybrreg:::klass_req(paste0("classifications/", id, "/codesAt"))
    expect_match(req$url, paste0("^", spec$services$klass, r$path), fixed = FALSE)
  }
})

test_that("http policy and org number rule match the request layer", {
  req <- tidybrreg:::brreg_req("enheter")
  expect_equal(req$options$useragent, spec$http$user_agent)
  expect_equal(req$headers$Accept, spec$http$accept)
  expect_equal(req$policies$retry_max_tries, spec$http$retry_max_tries)
  expect_equal(req$policies$throttle_rate %||% 5, spec$http$throttle_per_second_per_host)
  expect_true(grepl(spec$org_nr$pattern, "923609016"))
  expect_false(grepl(spec$org_nr$pattern, "123456789"))
})
