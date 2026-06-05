test_that("annotation_infotypes has expected structure", {
  expect_s3_class(annotation_infotypes, "tbl_df")
  expect_named(annotation_infotypes, c("code", "name_en"))
  expect_true(all(c("FADR", "NAVN") %in% annotation_infotypes$code))
  expect_false(anyNA(annotation_infotypes$code))
  expect_false(anyNA(annotation_infotypes$name_en))
  expect_false(anyDuplicated(annotation_infotypes$code) > 0)
})

test_that("lookup_infotype_vec translates known codes", {
  expect_equal(lookup_infotype_vec("FADR"), "Business address presumed incorrect")
  expect_equal(
    lookup_infotype_vec(c("KONT", "DAGL")),
    c("Missing contact person", "Missing general manager")
  )
})

test_that("lookup_infotype_vec passes through unknown codes and preserves NA", {
  expect_equal(lookup_infotype_vec("ZZZZ"), "ZZZZ")
  expect_equal(
    lookup_infotype_vec(c("FADR", "ZZZZ")),
    c("Business address presumed incorrect", "ZZZZ")
  )
  expect_true(is.na(lookup_infotype_vec(NA_character_)))
})

test_that("brreg_annotations translate adds infotype_desc after infotype", {
  fixture <- tibble::tibble(
    org_nr = c("111111111", "222222222"),
    position = c(0L, 0L),
    infotype = c("FADR", "ZZZZ"),
    tekst = c("a", "b"),
    innfoert_dato = c("2026-01-01", "2026-02-01")
  )
  testthat::local_mocked_bindings(read_state = function(...) fixture)
  res <- brreg_annotations(translate = TRUE)
  expect_true("infotype_desc" %in% names(res))
  expect_equal(
    which(names(res) == "infotype_desc"),
    which(names(res) == "infotype") + 1L
  )
  expect_equal(res$infotype_desc, c("Business address presumed incorrect", "ZZZZ"))
})

test_that("brreg_annotations without translate keeps the base schema", {
  fixture <- tibble::tibble(
    org_nr = "111111111", position = 0L, infotype = "FADR",
    tekst = "a", innfoert_dato = "2026-01-01"
  )
  testthat::local_mocked_bindings(read_state = function(...) fixture)
  res <- brreg_annotations()
  expect_false("infotype_desc" %in% names(res))
  expect_named(res, c("org_nr", "position", "infotype", "tekst", "innfoert_dato"))
})
