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
    nanoparquet::write_parquet(df, tmp)
  }
  file.rename(tmp, path)
}

#' Read a parquet file to tibble
#' @param path Path to parquet file.
#' @returns A tibble.
#' @keywords internal
read_parquet_safe <- function(path) {
  check_parquet_available()
  tier <- parquet_tier()
  if (tier == "arrow") {
    tibble::as_tibble(arrow::read_parquet(path))
  } else {
    tibble::as_tibble(nanoparquet::read_parquet(path))
  }
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
