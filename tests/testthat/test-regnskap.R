# Regnskapsregisteret accounts endpoint. The fixture is synthetic, built
# from the documented filing shape (OpenAPI 1.1.16) as observed after the
# 2026-10-01 change: three fiscal years per type, KONSERN before SELSKAP.
# The live suite (test-liveapi-audit.R) checks the shape against the API.

regnskap_fixture <- function() {
  jsonlite::read_json(test_path("fixtures", "regnskap_synthetic.json"))
}

test_that("flatten_regnskap returns one row per filing with the mapped columns", {
  res <- flatten_regnskap(regnskap_fixture(), "923609016")
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), 6L)
  expect_equal(names(res)[1], "org_nr")
  expect_true(all(res$org_nr == "923609016"))
  expect_equal(res$account_type, rep(c("KONSERN", "SELSKAP"), each = 3))
  expect_type(res$filing_id, "integer")
  expect_s3_class(res$period_end, "Date")
  expect_equal(res$period_end[6], as.Date("2025-06-30"))
  expect_type(res$total_assets, "double")
  expect_type(res$parent_company, "logical")
  expect_equal(res$parent_company, rep(c(TRUE, FALSE), each = 3))
  expect_equal(res$accounting_rules[1], "IFRS")
  expect_equal(res$total_equity + res$total_liabilities, res$total_equity_liabilities)
  expect_true(all(tidybrreg:::regnskap_dict$col_name %in% names(res)))
  expect_true(is.na(res$goodwill[1]))
  expect_false(any(is.na(res$goodwill[-1])))
})

test_that("flatten_regnskap passes unknown leaves through and reports coercion failures", {
  fx <- regnskap_fixture()[1:2]
  fx[[1]]$eiendeler$nyPost <- 12
  fx[[2]]$regnskapsperiode$tilDato <- "not a date"
  expect_warning(res <- flatten_regnskap(fx, "923609016"), class = "tidybrreg_warning_parse")
  expect_true("eiendeler_ny_post" %in% names(res))
  expect_equal(res$eiendeler_ny_post, c(12, NA))
  expect_true(is.na(res$period_end[2]))
  expect_equal(attr(res, "brreg_parse_problems")$column, "period_end")
})

test_that("flatten_regnskap of an empty array is the typed empty", {
  res <- flatten_regnskap(list(), "923609016")
  expect_equal(res, empty_regnskap())
})

test_that("brreg_regnskap requests the documented route and query", {
  q <- local_brreg_responses(list(stub_resp(200L, regnskap_fixture()),
                                  stub_resp(200L, list())))
  res <- brreg_regnskap("923609016")
  expect_equal(nrow(res), 6L)
  expect_match(q$requests[[1]]$url, "^https://data\\.brreg\\.no/regnskapsregisteret/regnskap/923609016$")
  brreg_regnskap("923609016", year = 2025, account_type = "SELSKAP")
  expect_match(q$requests[[2]]$url, "[?&]%C3%A5r=2025\\b")
  expect_match(q$requests[[2]]$url, "[?&]regnskapstype=SELSKAP\\b")
  expect_error(brreg_regnskap("923609016", account_type = "x"))
  expect_error(brreg_regnskap("123456789"), class = "tidybrreg_error_invalid_org_nr")
})

test_that("brreg_regnskap follows the satellite status contract", {
  local_brreg_responses(stub_resp(404L))
  expect_no_warning(res <- brreg_regnskap("923609016"))
  expect_equal(nrow(res), 0L)
  expect_equal(attr(res, "http_status"), 404L)
  expect_named(res, names(empty_regnskap()))

  local_brreg_responses(stub_resp(410L, list(slettedato = "2026-02-01")))
  expect_warning(res <- brreg_regnskap("923609016"), class = "tidybrreg_warning_deleted")
  expect_equal(attr(res, "http_status"), 410L)
  expect_equal(attr(res, "deletion_date"), as.Date("2026-02-01"))

  local_brreg_responses(stub_resp(500L, list(error = "boom")))
  expect_error(brreg_regnskap("923609016"), class = "tidybrreg_error_http")

  local_brreg_responses(stub_resp(200L, list()))
  res <- brreg_regnskap("923609016")
  expect_equal(nrow(res), 0L)
  expect_null(attr(res, "http_status"))
})

test_that("brreg_regnskap maps the unsupported accounting plan to a typed empty", {
  for (spelling in c("støttet", "stottet")) {
    msg <- paste0("Regnskapet inneholder en oppstillingsplan som ikke er ", spelling, " (BANK)")
    local_brreg_responses(stub_resp(500L, list(status = 500L, message = msg)))
    w <- NULL
    res <- withCallingHandlers(brreg_regnskap("984851006"),
                               tidybrreg_warning_unsupported_plan = function(cnd) {
                                 w <<- cnd
                                 invokeRestart("muffleWarning")
                               })
    expect_s3_class(w, "tidybrreg_warning_unsupported_plan")
    expect_equal(w$plan, "BANK")
    expect_equal(w$org_nr, "984851006")
    expect_equal(nrow(res), 0L)
    expect_equal(attr(res, "http_status"), 500L)
    expect_equal(attr(res, "unsupported_plan"), "BANK")
    expect_named(res, names(empty_regnskap()))
  }
})
