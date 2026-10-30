# BRREG returns addresses, vedtektsfestetFormaal and aktivitet as
# arrays of line-fragments. Element text contains commas and
# semicolons but never newlines, so only "\n" round-trips.

test_that("collapse_observed joins atomic arrays reversibly", {
  v <- list("Oppf\u00f8ring av bygningar, takarbeid (inkl. blikkenslagararbeid),",
            "murarbeid, stukkat\u00f8rarbeid og pussing og snekkararbeid.")
  out <- collapse_observed(v)
  expect_length(out, 1L)
  expect_equal(strsplit(out, "\n")[[1]], unlist(v))
})

test_that("collapse_observed nests object arrays as one row per element", {
  hist <- list(
    list(navn = "STATOIL ASA", fraDato = "2001-05-11 08:32:09",
         tilDato = "2007-10-01 06:44:33"),
    list(navn = "Den norske stats oljeselskap a.s",
         fraDato = "1995-03-12 16:23:00", tilDato = "2001-05-11 08:32:09")
  )
  out <- collapse_observed(hist)
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("navn", "fra_dato", "til_dato"))
  expect_equal(nrow(out), 2L)
  expect_equal(out$navn[1], "STATOIL ASA")
  expect_equal(out$til_dato[2], "2001-05-11 08:32:09")
})

test_that("collapse_observed handles empty and all-NULL inputs", {
  expect_true(is.na(collapse_observed(NULL)))
  expect_true(is.na(collapse_observed(list())))
  expect_true(is.na(collapse_observed(list(NULL, NULL))))
})

test_that("an array of objects becomes a list-column of tibbles on the entity row", {
  raw <- list(
    organisasjonsnummer = "923609016",
    navn = "EQUINOR ASA",
    historiskeNavn = list(
      list(navn = "STATOIL ASA", fraDato = "2001-05-11 08:32:09",
           tilDato = "2007-10-01 06:44:33")
    ),
    paategninger = list(
      list(infotype = "KONT", tekst = "Kontaktperson mangler", innfoertDato = "2025-05-05"),
      list(infotype = "FADR", tekst = "Adresse mangler", innfoertDato = "2025-06-06")
    )
  )
  flat <- flatten_json(raw)
  expect_s3_class(flat$historiskeNavn, "tbl_df")
  res <- parse_entity(raw)
  expect_equal(nrow(res), 1L)
  expect_type(res$historiske_navn, "list")
  expect_equal(res$historiske_navn[[1]]$navn, "STATOIL ASA")
  expect_type(res$annotations, "list")
  expect_equal(nrow(res$annotations[[1]]), 2L)
  expect_named(res$annotations[[1]], c("infotype", "tekst", "innfoert_dato"))
  unnested <- tidyr::unnest(res[, c("org_nr", "annotations")], "annotations")
  expect_equal(nrow(unnested), 2L)
  expect_equal(unnested$infotype, c("KONT", "FADR"))
})

test_that("an empty array emits no column, so a batch binds with and without it", {
  with_hist <- list(organisasjonsnummer = "1", navn = "A",
                    historiskeNavn = list(list(navn = "OLD", fraDato = "2000-01-01", tilDato = "2001-01-01")))
  without <- list(organisasjonsnummer = "2", navn = "B", historiskeNavn = list())
  expect_false("historiskeNavn" %in% names(flatten_json(without)))
  res <- parse_entities(list(with_hist, without))
  expect_equal(nrow(res), 2L)
  expect_type(res$historiske_navn, "list")
  expect_equal(res$historiske_navn[[1]]$navn, "OLD")
  expect_null(res$historiske_navn[[2]])
})

test_that("a nested list-column is never coerced by the dictionary type", {
  raw <- list(organisasjonsnummer = "923609016",
              paategninger = list(list(infotype = "KONT", tekst = "x")))
  res <- expect_no_warning(parse_entity(raw))
  expect_type(res$annotations, "list")
  expect_null(attr(res, "brreg_parse_problems"))
})

test_that("flatten_json and flatten_cell agree on the same array", {
  addr <- list("c/o Front Real Estate AS", "Fridtjof Nansens plass 4")
  via_json <- flatten_json(list(forretningsadresse = list(adresse = addr)))
  expect_equal(via_json[["forretningsadresse.adresse"]],
               flatten_cell(addr))
  expect_equal(flatten_cell(unlist(addr)), flatten_cell(addr))
})

test_that("single-element arrays stay bare, not JSON", {
  expect_equal(collapse_observed(list("Gruva 15")), "Gruva 15")
  expect_equal(flatten_cell(list("Gruva 15")), "Gruva 15")
})

test_that("flatten_cell nests data frames and serializes single objects", {
  kapital <- list(belop = 1000, valuta = "NOK")
  expect_equal(jsonlite::fromJSON(flatten_cell(kapital))$belop, 1000)
  df <- data.frame(infotype = "KONT", tekst = "x", innfoertDato = "2025-01-01")
  cell <- flatten_cell(df)
  expect_s3_class(cell, "tbl_df")
  expect_named(cell, c("infotype", "tekst", "innfoert_dato"))
})

test_that("the bulk JSON path keeps arrays of objects as a list-column", {
  dat <- tibble::tibble(
    organisasjonsnummer = c("1", "2", "3"),
    paategninger = list(data.frame(infotype = "KONT", tekst = "x"), NULL, list()),
    forretningsadresse.adresse = list(c("Line 1", "Line 2"), "One", NULL)
  )
  out <- flatten_list_columns(dat)
  expect_type(out$paategninger, "list")
  expect_equal(out$paategninger[[1]]$infotype, "KONT")
  expect_null(out$paategninger[[2]])
  expect_null(out$paategninger[[3]])
  expect_equal(out$forretningsadresse.adresse, c("Line 1\nLine 2", "One", NA))
  res <- expect_no_warning(rename_and_coerce(out))
  expect_type(res$annotations, "list")
  expect_equal(res$business_address[1], "Line 1\nLine 2")
})
