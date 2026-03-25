#' Detect available parquet backend
#'
#' Returns the best available parquet library. Prefers \pkg{arrow}
#' (full-featured, supports cloud storage) over \pkg{nanoparquet}
#' (lightweight, local only).
#'
#' @returns One of `"arrow"`, `"nanoparquet"`, or `"none"`.
#' @keywords internal
parquet_tier <- function() {
  if (requireNamespace("arrow", quietly = TRUE)) return("arrow")
  if (requireNamespace("nanoparquet", quietly = TRUE)) return("nanoparquet")
  "none"
}


#' Write a data frame to parquet
#'
#' On local paths, writes to a temporary file first then renames for
#' atomicity. On cloud URIs (`gs://`, `s3://`), writes directly via
#' [arrow::write_parquet()] — cloud object stores provide their own
#' atomicity guarantees. Dispatches to \pkg{nanoparquet} when
#' \pkg{arrow} is unavailable and the path is local.
#'
#' @param df A data frame or tibble.
#' @param path Target file path or cloud URI.
#'
#' @returns The path (invisibly).
#'
#' @keywords internal
write_parquet_safe <- function(df, path) {
  check_parquet_available()

  if (is_cloud_path(path)) {
    check_cloud_arrow(path)
    arrow::write_parquet(df, path)
    return(invisible(path))
  }

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
  invisible(path)
}


#' Read a parquet file to tibble
#'
#' Cloud URIs require \pkg{arrow}. Local paths dispatch to
#' \pkg{nanoparquet} when \pkg{arrow} is unavailable.
#'
#' @param path Path or cloud URI to a parquet file.
#'
#' @returns A [tibble][tibble::tibble-package].
#'
#' @keywords internal
read_parquet_safe <- function(path) {
  check_parquet_available()

  if (is_cloud_path(path)) {
    check_cloud_arrow(path)
    return(tibble::as_tibble(arrow::read_parquet(path)))
  }

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
