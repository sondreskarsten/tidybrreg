# Regnskapsregisteret accounts endpoint. The fixture holds 60 real filings
# from the brreg-json-fetcher data-2026-10 release (collected 2026-10-06 to
# 2026-10-08 from the live API; NLOD 2.0, Brønnøysundregistrene), chosen so
# that every leaf path of the 1,129,601-filing population occurs both
# present and absent, every accounting identity fails at least once, and
# every currency and account type appears. The .expected.json next to it
# was computed independently in Python (data-raw/regnskap) and pins the
# item paths and the consistency flags of every filing.

regnskap_fixture <- function() {
  jsonlite::read_json(test_path("fixtures", "regnskap_release_2026-10.json"))
}
regnskap_expected <- function() {
  jsonlite::read_json(test_path("fixtures", "regnskap_release_2026-10.expected.json"))
}

test_that("flatten_regnskap nests one row per filing with typed scalars and items", {
  res <- flatten_regnskap(regnskap_fixture(), "923609016")
  exp <- regnskap_expected()
  expect_s3_class(res, "tbl_df")
  expect_equal(nrow(res), length(exp))
  expect_equal(names(res)[1], "org_nr")
  expect_equal(res$org_nr, vapply(exp, \(e) e$org_nr, character(1)))
  expect_equal(res$filing_id, vapply(exp, \(e) as.integer(e$filing_id), integer(1)))
  expect_type(res$filing_id, "integer")
  expect_s3_class(res$period_start, "Date")
  expect_s3_class(res$period_end, "Date")
  expect_false(anyNA(res$period_end))
  expect_true(all(res$account_type %in% c("SELSKAP", "KONSERN")))
  expect_true(all(c("SELSKAP", "KONSERN") %in% res$account_type))
  expect_true("EDT" %in% res$currency)
  expect_type(res$parent_company, "logical")
  expect_type(res$small_enterprise, "logical")
  expect_type(res$items, "list")
  expect_true(all(vapply(res$items, inherits, logical(1), "tbl_df")))
  expect_equal(vapply(res$items, nrow, integer(1)), vapply(exp, \(e) as.integer(e$n_items), integer(1)))
  scalar <- setdiff(names(res), c("items", "consistent", "inconsistencies"))
  expect_true(all(scalar %in% regnskap_dict$col_name))
  in_statement <- grepl("^(eiendeler|egenkapitalGjeld|resultatregnskapResultat)\\.", regnskap_dict$api_path)
  expect_false(any(regnskap_dict$col_name[in_statement] %in% names(res)))
})

test_that("items keep the API's structure: statement, group, item, path, level, is_sum, value", {
  res <- flatten_regnskap(regnskap_fixture(), "923609016")
  exp <- regnskap_expected()
  items <- res$items[[1]]
  expect_named(items, c("statement", "group", "item", "path", "level", "is_sum", "value"))
  expect_type(items$value, "double")
  expect_type(items$level, "integer")
  expect_type(items$is_sum, "logical")
  for (i in seq_along(exp)) {
    expect_setequal(res$items[[i]]$path, unlist(exp[[i]]$item_paths))
  }
  all_items <- dplyr::bind_rows(res$items)
  expect_true(all(all_items$statement %in% c("assets", "equity_liabilities", "income_statement")))
  expect_equal(unique(all_items$group[all_items$path == "eiendeler.omloepsmidler.sumOmloepsmidler"]), "current_assets")
  expect_equal(unique(all_items$item[all_items$path == "eiendeler.omloepsmidler.sumOmloepsmidler"]), "current_assets")
  expect_equal(unique(all_items$group[all_items$path == "eiendeler.sumBankinnskuddOgKontanter"]), "assets")
  expect_equal(unique(all_items$item[all_items$path == "eiendeler.sumEiendeler"]), "total_assets")
  expect_equal(unique(all_items$level[all_items$path == "eiendeler.sumEiendeler"]), 1L)
  expect_equal(unique(all_items$level[all_items$path == "resultatregnskapResultat.driftsresultat.driftsinntekter.salgsinntekter"]), 3L)
  expect_true(all(all_items$is_sum[all_items$path == "eiendeler.sumEiendeler"]))
  expect_false(any(all_items$is_sum[all_items$path == "resultatregnskapResultat.aarsresultat"]))
  expect_true(all(all_items$item %in% regnskap_dict$col_name))
  expect_false(anyNA(all_items$value))
  in_statement <- grepl("^(eiendeler|egenkapitalGjeld|resultatregnskapResultat)\\.", regnskap_dict$api_path)
  expect_setequal(unique(all_items$path), regnskap_dict$api_path[in_statement])
})

test_that("consistency flags equal the independent Python check of the same identities", {
  res <- flatten_regnskap(regnskap_fixture(), "923609016")
  exp <- regnskap_expected()
  expected_consistent <- vapply(exp, \(e) if (is.null(e$consistent)) NA else isTRUE(e$consistent), logical(1))
  expect_equal(res$consistent, expected_consistent)
  expected_inc <- vapply(exp, \(e) if (length(e$inconsistencies) == 0) NA_character_ else paste(unlist(e$inconsistencies), collapse = "\n"), character(1))
  expect_equal(res$inconsistencies, expected_inc)
  expect_true(any(res$consistent %in% FALSE))
  expect_true(any(res$consistent %in% TRUE))
  expect_true(all(is.na(res$inconsistencies[res$consistent %in% TRUE])))
})

test_that("the identities are checked within the tolerance and only when checkable", {
  f <- regnskap_fixture()[[1]]
  f$eiendeler$sumEiendeler <- f$egenkapitalGjeld$sumEgenkapitalGjeld + 1
  res <- flatten_regnskap(list(f), "923609016")
  expect_false("balance" %in% strsplit(res$inconsistencies %||% "", "\n")[[1]])
  f$eiendeler$sumEiendeler <- f$egenkapitalGjeld$sumEgenkapitalGjeld + 2
  res <- flatten_regnskap(list(f), "923609016")
  expect_false(res$consistent)
  expect_true("balance" %in% strsplit(res$inconsistencies, "\n")[[1]])
  g <- list(id = 1L, journalnr = "x", regnskapstype = "SELSKAP",
            virksomhet = list(organisasjonsnummer = "923609016"),
            regnskapsperiode = list(fraDato = "2025-01-01", tilDato = "2025-12-31"),
            valuta = "NOK", eiendeler = list(sumEiendeler = 10))
  res <- flatten_regnskap(list(g), "923609016")
  expect_true(is.na(res$consistent))
  expect_true(is.na(res$inconsistencies))
  expect_equal(nrow(res$items[[1]]), 1L)
})

test_that("unknown leaves pass through as items or scalar columns and bad values are reported", {
  f <- regnskap_fixture()[[1]]
  f$eiendeler$nyPost <- 12
  f$eiendeler$nyGruppe <- list(sumNyGruppe = 5)
  f$nyttFelt <- "x"
  f$kontantstroem <- list(netto = 3)
  res <- flatten_regnskap(list(f), "923609016")
  items <- res$items[[1]]
  expect_equal(items$item[items$path == "eiendeler.nyPost"], "ny_post")
  expect_equal(items$group[items$path == "eiendeler.nyPost"], "assets")
  expect_equal(items$group[items$path == "eiendeler.nyGruppe.sumNyGruppe"], "ny_gruppe")
  expect_true(items$is_sum[items$path == "eiendeler.nyGruppe.sumNyGruppe"])
  expect_equal(res$nytt_felt, "x")
  expect_equal(res$kontantstroem_netto, 3)

  g <- regnskap_fixture()[[2]]
  g$eiendeler$sumEiendeler <- "ikke et tall"
  g$regnskapsperiode$tilDato <- "not a date"
  expect_warning(res <- flatten_regnskap(list(f, g), "923609016"), class = "tidybrreg_warning_parse")
  problems <- attr(res, "brreg_parse_problems")
  expect_setequal(problems$column, c("items.value", "period_end"))
  expect_equal(problems$row[problems$column == "items.value"], 2L)
  expect_equal(problems$actual[problems$column == "items.value"], "ikke et tall")
  expect_true(is.na(res$items[[2]]$value[res$items[[2]]$path == "eiendeler.sumEiendeler"]))
  expect_true(is.na(res$period_end[2]))
})

test_that("an empty statement object contributes no items, as absent does", {
  f <- regnskap_fixture()[[1]]
  f$resultatregnskapResultat <- jsonlite::fromJSON("{}", simplifyVector = FALSE)
  res <- flatten_regnskap(list(f), "923609016")
  expect_false(any(res$items[[1]]$statement == "income_statement"))
})

test_that("flatten_regnskap of an empty array is the typed empty", {
  expect_equal(flatten_regnskap(list(), "923609016"), empty_regnskap())
})

test_that("brreg_regnskap requests the documented route and query", {
  q <- local_brreg_responses(list(stub_resp(200L, regnskap_fixture()[1:3]),
                                  stub_resp(200L, list())))
  res <- brreg_regnskap("923609016")
  expect_equal(nrow(res), 3L)
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

# Population check against a brreg-json-fetcher data release. Set
# TIDYBRREG_REGNSKAP_SCAN to a directory holding the outputs of
# data-raw/regnskap/scan_population.py (population_paths.json and
# shape_examples.json: one real filing per distinct structural shape of
# the release). Every path the population carries must be captured, no
# value may fail to parse, and every filing must flatten.
test_that("every structural shape of the published population flattens without loss", {
  dir <- Sys.getenv("TIDYBRREG_REGNSKAP_SCAN", "")
  skip_if(!nzchar(dir) || !file.exists(file.path(dir, "shape_examples.json")), "no population scan")
  pop <- jsonlite::read_json(file.path(dir, "population_paths.json"))
  shapes <- jsonlite::read_json(file.path(dir, "shape_examples.json"))
  res <- flatten_regnskap(shapes, "000000000")
  expect_equal(nrow(res), length(shapes))
  expect_null(attr(res, "brreg_parse_problems"))
  leaf_paths <- names(pop$paths)[vapply(pop$paths, \(p) !identical(names(p$types), "empty_object"), logical(1))]
  captured_items <- unique(unlist(lapply(res$items, \(it) it$path)))
  scalar_cols <- setdiff(names(res), c("items", "consistent", "inconsistencies"))
  captured_scalars <- regnskap_dict$api_path[match(scalar_cols, regnskap_dict$col_name)]
  expect_setequal(c(captured_items, captured_scalars), leaf_paths)
  expect_true(all(res$consistent %in% c(TRUE, FALSE, NA)))
  expect_gt(mean(res$consistent, na.rm = TRUE), 0.5)
})
