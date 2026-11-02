test_that("nested list-columns survive a nanoparquet round trip as tibbles", {
  skip_if_not_installed("nanoparquet")
  df <- tibble::tibble(
    org_nr = c("1", "2", "3"),
    historiske_navn = list(tibble::tibble(navn = c("A", "B"), fra_dato = c("2001-01-01", NA)), NULL,
                           tibble::tibble(navn = "C", fra_dato = "2003-03-03")),
    n = 1:3
  )
  flat <- nested_to_json(df)
  expect_equal(flat$columns, "historiske_navn")
  expect_type(flat$df$historiske_navn, "character")
  expect_true(is.na(flat$df$historiske_navn[2]))
  f <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(flat$df, f,
                             metadata = c(tidybrregpanel_json_columns = "historiske_navn"))
  expect_equal(json_columns_of(f), "historiske_navn")
  back <- read_parquet_safe(f)
  expect_type(back$historiske_navn, "list")
  expect_null(back$historiske_navn[[2]])
  expect_equal(back$historiske_navn[[1]]$navn, c("A", "B"))
  expect_true(is.na(back$historiske_navn[[1]]$fra_dato[2]))
  expect_equal(back$historiske_navn[[3]]$navn, "C")
  expect_equal(back$n, 1:3)
})

test_that("an arrow round trip gives plain lists that bind with fresh entity rows", {
  skip_if_not_installed("arrow")
  df <- tibble::tibble(org_nr = c("1", "2"),
                       historiske_navn = list(tibble::tibble(navn = "A", fra_dato = "2001-01-01"), NULL))
  f <- withr::local_tempfile(fileext = ".parquet")
  write_parquet_safe(df, f)
  back <- read_parquet_safe(f)
  expect_false(inherits(back$historiske_navn, "vctrs_list_of"))
  expect_type(back$historiske_navn, "list")
  expect_null(back$historiske_navn[[2]])
  fresh <- tibble::tibble(org_nr = "3", historiske_navn = list(tibble::tibble(navn = "B", fra_dato = "2002-02-02")))
  na_row <- tibble::tibble(org_nr = "4", historiske_navn = NA)
  bound <- dplyr::bind_rows(back, fresh, na_row)
  expect_equal(nrow(bound), 4L)
  expect_equal(bound$historiske_navn[[3]]$navn, "B")
  expect_null(bound$historiske_navn[[4]])
})

test_that("write_parquet_safe writes a nested column with whichever backend is installed", {
  df <- tibble::tibble(org_nr = "1", annotations = list(tibble::tibble(tekst = "x")))
  f <- withr::local_tempfile(fileext = ".parquet")
  write_parquet_safe(df, f)
  back <- read_parquet_safe(f)
  expect_equal(back$annotations[[1]]$tekst, "x")
})
