# konsernstruktur endpoint added by BRREG 2026-06-24. Fixture is the
# live Equinor response captured 2026-08-04: 53 subsidiaries, depth 2+.

equinor_konsern <- function() {
  jsonlite::read_json(test_path("fixtures", "konsernstruktur_equinor.json"))
}

test_that("flatten_konsern returns one row per node with synthesized root", {
  res <- flatten_konsern(equinor_konsern(), "923609016")
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 54L)
  expect_named(res, c("org_nr", "node_org_nr", "node_name", "level",
                      "link_form", "link_form_desc", "basis",
                      "relation_date", "parent_org_nr", "parent_name",
                      "legal_form", "legal_form_desc"))

  root <- res[res$level == 0L, ]
  expect_equal(nrow(root), 1L)
  expect_equal(root$node_org_nr, "923609016")
  expect_equal(root$link_form, "KKKK")
  expect_equal(root$link_form_desc, "\u00d8verste mor")
  expect_true(is.na(root$parent_org_nr))
  expect_true(is.na(root$relation_date))
})

test_that("flatten_konsern children carry observed KDAT links and dates", {
  res <- flatten_konsern(equinor_konsern(), "923609016")
  kids <- res[res$level > 0L, ]
  expect_equal(nrow(kids), 53L)
  expect_true(all(kids$link_form == "KDAT"))
  expect_false(any(is.na(kids$basis)))
  expect_true("100%" %in% kids$basis)
  expect_true("95,00%" %in% kids$basis)
  expect_s3_class(res$relation_date, "Date")
  expect_false(any(is.na(kids$relation_date)))
  expect_true(any(res$level == 2L))
})

test_that("flatten_konsern parent linkage is internally consistent", {
  res <- flatten_konsern(equinor_konsern(), "923609016")
  kids <- res[res$level > 0L, ]
  expect_true(all(kids$parent_org_nr %in% res$node_org_nr))
  l2 <- res[res$level == 2L, ]
  expect_true(all(l2$parent_org_nr %in% res$node_org_nr[res$level == 1L]))
  energy_kids <- res[res$parent_org_nr %in% "990888213", ]
  expect_true(nrow(energy_kids) > 0)
  expect_true(all(energy_kids$parent_name == "EQUINOR ENERGY AS"))
})

test_that("brreg_konsern returns a typed empty tibble on 404 without warning", {
  testthat::local_mocked_bindings(
    brreg_req = function(...) structure(list(), class = "httr2_request")
  )
  testthat::local_mocked_bindings(
    req_error = function(req, ...) req,
    req_perform = function(req) structure(list(), class = "stub_resp"),
    resp_status = function(resp) 404L,
    .package = "httr2"
  )
  expect_no_warning(res <- brreg_konsern("810034882"))
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 0L)
  expect_equal(attr(res, "http_status"), 404L)
  expect_named(res, names(tidybrreg:::empty_konsern()))
})
