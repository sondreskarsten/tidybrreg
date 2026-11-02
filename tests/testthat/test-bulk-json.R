# The bulk JSON reader streams the array in batches of complete objects so
# the whole decoded tree is never in memory. These tests drive the byte
# scanner across chunk boundaries that split strings, escapes and objects.

bulk_fixture <- function(n, pretty = TRUE, every = 7L) {
  f <- withr::local_tempfile(fileext = ".json.gz", .local_envir = parent.frame())
  con <- gzfile(f, "w")
  arr <- lapply(seq_len(n), function(i) list(
    organisasjonsnummer = sprintf("9%08d", i),
    navn = sprintf("Firma {\"x\"} \\ } %d", i),
    organisasjonsform = list(kode = "AS"),
    antallAnsatte = i,
    forretningsadresse = list(adresse = list("L1", "L2")),
    paategninger = if (i %% every == 0) list(list(infotype = "KONT", tekst = "x}")) else list(),
    note = "esc\"quote\\\\"
  ))
  writeLines(jsonlite::toJSON(arr, auto_unbox = TRUE, pretty = pretty), con)
  close(con)
  f
}

test_that("read_json_objects emits every object once whatever the chunk boundaries", {
  for (pretty in c(TRUE, FALSE)) {
    f <- bulk_fixture(300L, pretty = pretty)
    for (cs in c(5L, 37L, 1000L, 1048576L)) {
      seen <- character()
      n <- read_json_objects(f, function(text) {
        d <- jsonlite::fromJSON(text)
        seen <<- c(seen, d$organisasjonsnummer)
      }, batch_size = 70L, chunk_size = cs)
      expect_equal(n, 300L, info = paste(pretty, cs))
      expect_equal(seen, sprintf("9%08d", 1:300), info = paste(pretty, cs))
    }
  }
})

test_that("read_json_objects honours n_max and batch_size", {
  f <- bulk_fixture(50L)
  sizes <- integer()
  n <- read_json_objects(f, function(text) sizes <<- c(sizes, nrow(jsonlite::fromJSON(text))),
                         n_max = 23L, batch_size = 10L)
  expect_equal(n, 23L)
  expect_equal(sizes, c(10L, 10L, 3L))
  expect_equal(jsonlite::fromJSON(read_json_head(f, 4))$organisasjonsnummer, sprintf("9%08d", 1:4))
  expect_equal(read_json_head(withr::local_tempfile(fileext = ".json", pattern = "e") |>
                                (\(p) { writeLines("[]", p); p })(), 3), "[]")
})

test_that("parse_bulk_json gives the same tibble batched as whole, with the tidy shape", {
  f <- bulk_fixture(120L)
  whole <- parse_bulk_json(f)
  batched <- local({
    batches <- list()
    read_json_objects(f, function(text) {
      d <- jsonlite::fromJSON(text, flatten = TRUE)
      batches[[length(batches) + 1L]] <<- drop_hal_links(flatten_list_columns(tibble::as_tibble(d)))
    }, batch_size = 11L, chunk_size = 2048L)
    rename_and_coerce(dplyr::bind_rows(batches))
  })
  expect_equal(batched, whole)
  expect_equal(nrow(whole), 120L)
  expect_type(whole$annotations, "list")
  expect_equal(sum(!vapply(whole$annotations, is.null, logical(1))), 17L)
  expect_equal(whole$annotations[[7]]$tekst, "x}")
  expect_equal(whole$business_address[1], "L1\nL2")
  expect_equal(whole$name[3], "Firma {\"x\"} \\ } 3")
  expect_type(whole$employees, "integer")
  head5 <- parse_bulk_json(f, n_max = 5)
  expect_equal(head5$org_nr, whole$org_nr[1:5])
  expect_false("annotations" %in% names(head5))
})

test_that("a batch where every array is empty drops the column so batches bind", {
  dat <- tibble::tibble(organisasjonsnummer = c("1", "2"),
                        paategninger = list(list(), NULL),
                        forretningsadresse.adresse = list(c("A", "B"), character()))
  out <- flatten_list_columns(dat)
  expect_false("paategninger" %in% names(out))
  expect_equal(out$forretningsadresse.adresse, c("A\nB", NA))
})

test_that("bind_batches binds like bind_rows, filling columns a batch did not carry", {
  a <- tibble::tibble(x = c("1", "2"), n = 1:2, nested = list(tibble::tibble(v = "a"), NULL))
  b <- tibble::tibble(x = "3", flag = TRUE)
  c <- tibble::tibble(x = c("4", "5"), n = c(4.5, NA), nested = list(NULL, tibble::tibble(v = "e")))
  out <- bind_batches(list(a, b, c))
  expect_equal(out, dplyr::bind_rows(a, b, c))
  expect_equal(names(out), c("x", "n", "nested", "flag"))
  expect_equal(out$n, c(1, 2, NA, 4.5, NA))
  expect_equal(out$flag, c(NA, NA, TRUE, NA, NA))
  expect_null(out$nested[[3]])
  expect_equal(out$nested[[5]]$v, "e")
  expect_equal(nrow(bind_batches(list(a))), 2L)
})
