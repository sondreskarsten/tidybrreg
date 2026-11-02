#' Detect available parquet backend
#' @returns One of `"arrow"`, `"nanoparquet"`, or `"none"`.
#' @keywords internal
parquet_tier <- function() {
  if (requireNamespace("arrow", quietly = TRUE)) return("arrow")
  if (requireNamespace("nanoparquet", quietly = TRUE)) return("nanoparquet")
  "none"
}

#' Write a data frame to parquet atomically
#'
#' Writes to a temporary file first, then renames to the target path.
#' Dispatches to arrow or nanoparquet depending on availability.
#'
#' @param df A data frame.
#' @param path Target file path.
#' @keywords internal
write_parquet_safe <- function(df, path) {
  check_parquet_available()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(tmpdir = dirname(path), fileext = ".parquet")
  on.exit(unlink(tmp), add = TRUE)
  tier <- parquet_tier()
  if (tier == "arrow") {
    arrow::write_parquet(df, tmp)
  } else {
    flat <- nested_to_json(df)
    meta <- if (length(flat$columns) > 0) {
      c(tidybrregpanel_json_columns = paste(flat$columns, collapse = ","))
    }
    nanoparquet::write_parquet(flat$df, tmp, metadata = meta)
  }
  file.rename(tmp, path)
}

#' Serialize nested list-columns to JSON text for a flat parquet writer
#'
#' nanoparquet writes no nested types, so each list-column (the tidy
#' `historiske_navn` and `annotations` columns, one tibble per row) is
#' written as the JSON array of its rows, `NA` where the row has none.
#' The column names travel in the file's key-value metadata so
#' [read_parquet_safe()] restores the tibbles; arrow keeps the nested
#' type and needs neither.
#' @param df A data frame.
#' @returns A list with `df` (list-columns replaced by character) and
#'   `columns` (the names that were serialized).
#' @keywords internal
nested_to_json <- function(df) {
  cols <- names(df)[vapply(df, is.list, logical(1))]
  for (col in cols) {
    df[[col]] <- vapply(df[[col]], function(v) {
      if (is.null(v) || length(v) == 0) return(NA_character_)
      as.character(jsonlite::toJSON(v, dataframe = "rows", na = "null", auto_unbox = TRUE))
    }, character(1))
  }
  list(df = df, columns = cols)
}

#' Restore nested list-columns that [nested_to_json()] serialized
#' @param df A data frame read from parquet.
#' @param cols Column names holding JSON arrays of rows.
#' @returns `df` with those columns as lists of tibbles, `NULL` where
#'   the text was `NA`.
#' @keywords internal
json_to_nested <- function(df, cols) {
  for (col in intersect(cols, names(df))) {
    df[[col]] <- lapply(df[[col]], function(txt) {
      if (is.na(txt)) return(NULL)
      tibble::as_tibble(jsonlite::fromJSON(txt))
    })
  }
  df
}

#' Column names a nanoparquet writer serialized to JSON, from the file metadata
#' @keywords internal
json_columns_of <- function(path) {
  key <- "tidybrregpanel_json_columns"
  value <- if (requireNamespace("nanoparquet", quietly = TRUE)) {
    kv <- nanoparquet::read_parquet_metadata(path)$file_meta_data$key_value_metadata[[1]]
    if (is.null(kv)) NULL else kv$value[kv$key == key]
  } else {
    arrow::read_parquet(path, as_data_frame = FALSE)$metadata[[key]]
  }
  if (is.null(value) || length(value) == 0) return(character())
  strsplit(value, ",", fixed = TRUE)[[1]]
}

#' Read a parquet file to tibble
#'
#' Nested list-columns come back as plain lists of tibbles whichever
#' writer produced the file: arrow's `list_of` vectors are unclassed so
#' they bind with the plain lists [tidybrreg::brreg_entity()] returns,
#' and columns a nanoparquet writer serialized to JSON text are parsed
#' back into tibbles.
#' @param path Path to parquet file.
#' @returns A tibble.
#' @keywords internal
read_parquet_safe <- function(path) {
  check_parquet_available()
  tier <- parquet_tier()
  df <- if (tier == "arrow") {
    tibble::as_tibble(arrow::read_parquet(path))
  } else {
    tibble::as_tibble(nanoparquet::read_parquet(path))
  }
  for (col in names(df)) {
    if (inherits(df[[col]], "vctrs_list_of")) df[[col]] <- as.list(df[[col]])
  }
  json_to_nested(df, json_columns_of(path))
}

#' Abort if no parquet backend available
#' @keywords internal
check_parquet_available <- function() {
  if (parquet_tier() == "none") {
    cli::cli_abort(c(
      "A parquet backend is required for snapshot operations.",
      "i" = "Install {.pkg nanoparquet} (lightweight) or {.pkg arrow} (full-featured):",
      " " = "{.code install.packages(\"nanoparquet\")}"
    ))
  }
}
