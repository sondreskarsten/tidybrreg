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

test_that("collapse_observed serializes object arrays instead of joining", {
  hist <- list(
    list(navn = "STATOIL ASA", fraDato = "2001-05-11 08:32:09",
         tilDato = "2007-10-01 06:44:33"),
    list(navn = "Den norske stats oljeselskap a.s",
         fraDato = "1995-03-12 16:23:00", tilDato = "2001-05-11 08:32:09")
  )
  out <- collapse_observed(hist)
  parsed <- jsonlite::fromJSON(out)
  expect_s3_class(parsed, "data.frame")
  expect_equal(nrow(parsed), 2L)
  expect_equal(parsed$navn[1], "STATOIL ASA")
  expect_equal(parsed$tilDato[2], "2001-05-11 08:32:09")
})

test_that("collapse_observed handles empty and all-NULL inputs", {
  expect_true(is.na(collapse_observed(NULL)))
  expect_true(is.na(collapse_observed(list())))
  expect_true(is.na(collapse_observed(list(NULL, NULL))))
})

test_that("flatten_json no longer mangles historiskeNavn", {
  raw <- list(
    organisasjonsnummer = "923609016",
    navn = "EQUINOR ASA",
    historiskeNavn = list(
      list(navn = "STATOIL ASA", fraDato = "2001-05-11 08:32:09",
           tilDato = "2007-10-01 06:44:33")
    )
  )
  flat <- flatten_json(raw)
  parsed <- jsonlite::fromJSON(flat$historiskeNavn)
  expect_equal(parsed$navn, "STATOIL ASA")
  expect_false(grepl("^STATOIL ASA, ", flat$historiskeNavn))
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

test_that("flatten_cell still serializes single objects and data frames", {
  kapital <- list(belop = 1000, valuta = "NOK")
  expect_equal(jsonlite::fromJSON(flatten_cell(kapital))$belop, 1000)
  df <- data.frame(infotype = "KONT", tekst = "x")
  expect_equal(jsonlite::fromJSON(flatten_cell(df))$infotype, "KONT")
})
