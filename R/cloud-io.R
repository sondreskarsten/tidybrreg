#' Cloud and local storage abstraction
#'
#' Internal helpers that let tidybrreg I/O functions work transparently
#' on local file paths, GCS (`gs://`) URIs, and S3 (`s3://`) URIs.
#' Cloud storage requires the \pkg{arrow} package compiled with
#' GCS and/or S3 support (`arrow::arrow_with_gcs()`,
#' `arrow::arrow_with_s3()`).
#'
#' @name cloud-io
#' @keywords internal
NULL


#' Detect whether a path is a cloud storage URI
#'
#' Recognises `gs://` (Google Cloud Storage) and `s3://` (Amazon S3 /
#' S3-compatible) scheme prefixes.
#'
#' @param path Character scalar. A file path or URI.
#'
#' @returns `TRUE` if `path` starts with `gs://` or `s3://`, `FALSE`
#'   otherwise.
#'
#' @keywords internal
is_cloud_path <- function(path) {
  grepl("^(gs|s3)://", path)
}


#' Validate arrow cloud support for a storage URI
#'
#' Aborts with a user-friendly message if \pkg{arrow} is not installed
#' or lacks the required cloud filesystem support for the URI scheme.
#' No-op for local paths.
#'
#' @param path Character scalar. A file path or URI.
#'
#' @returns `NULL` (invisibly). Called for its side effect.
#'
#' @keywords internal
check_cloud_arrow <- function(path) {
  if (!is_cloud_path(path)) return(invisible(NULL))
  if (!requireNamespace("arrow", quietly = TRUE)) {
    cli::cli_abort("Cloud storage paths require the {.pkg arrow} package.")
  }
  scheme <- sub("://.*", "", path)
  if (scheme == "gs" && !arrow::arrow_with_gcs()) {
    cli::cli_abort(
      "Arrow GCS support not available. Install from r-universe or rebuild with {.envvar ARROW_GCS=ON}."
    )
  }
  if (scheme == "s3" && !arrow::arrow_with_s3()) {
    cli::cli_abort(
      "Arrow S3 support not available. Rebuild with {.envvar ARROW_S3=ON}."
    )
  }
  invisible(NULL)
}


#' Check file existence on local or cloud storage
#'
#' Delegates to [base::file.exists()] for local paths or
#' `arrow::FileSystem$from_uri()` with `GetFileInfo()` for cloud URIs.
#'
#' @param path Character scalar. A file path or URI.
#'
#' @returns `TRUE` if the file exists, `FALSE` otherwise.
#'
#' @keywords internal
cloud_file_exists <- function(path) {
  if (!is_cloud_path(path)) return(file.exists(path))
  check_cloud_arrow(path)
  resolved <- arrow::FileSystem$from_uri(path)
  info <- resolved$fs$GetFileInfo(resolved$path)
  if (is.list(info) && !inherits(info, "FileInfo")) info <- info[[1]]
  info$type != 0L
}


#' Retrieve file metadata from local or cloud storage
#'
#' Returns size (bytes) and modification time for a single file.
#' Uses [base::file.info()] locally and arrow `GetFileInfo()` on
#' cloud URIs.
#'
#' @param path Character scalar. A file path or URI.
#'
#' @returns A list with `exists` (logical), `size` (numeric, bytes),
#'   and `mtime` (POSIXct or `NA`). If the file does not exist,
#'   `exists` is `FALSE` and other fields are `NA`/`0`.
#'
#' @keywords internal
cloud_file_info <- function(path) {
  absent <- list(exists = FALSE, size = 0, mtime = NA_real_)

  if (!is_cloud_path(path)) {
    if (!file.exists(path)) return(absent)
    info <- file.info(path)
    return(list(exists = TRUE, size = info$size, mtime = info$mtime))
  }

  check_cloud_arrow(path)
  resolved <- arrow::FileSystem$from_uri(path)
  info <- resolved$fs$GetFileInfo(resolved$path)
  if (is.list(info) && !inherits(info, "FileInfo")) info <- info[[1]]
  if (info$type == 0L) return(absent)

  list(exists = TRUE, size = info$size, mtime = info$mtime)
}


#' List files under a directory on local or cloud storage
#'
#' Returns paths to files matching `pattern` under `dir_path`.
#' Uses [base::list.files()] locally. On cloud URIs, uses
#' `arrow::FileSelector` with recursive traversal and filters by
#' file type.
#'
#' @param dir_path Character scalar. A directory path or URI.
#' @param pattern Optional regex to filter file names (applied to
#'   [base::basename()] of each entry).
#' @param recursive Logical. Recurse into subdirectories.
#'
#' @returns Character vector of full file paths/URIs.
#'
#' @keywords internal
cloud_list_files <- function(dir_path, pattern = NULL, recursive = TRUE) {
  if (!is_cloud_path(dir_path)) {
    return(list.files(dir_path, pattern = pattern,
                      recursive = recursive, full.names = TRUE))
  }
  check_cloud_arrow(dir_path)
  resolved <- arrow::FileSystem$from_uri(dir_path)
  sel <- arrow::FileSelector$create(resolved$path, recursive = recursive)
  entries <- tryCatch(
    resolved$fs$GetFileInfo(sel),
    error = function(e) list()
  )
  paths <- vapply(entries, function(e) {
    if (e$type == 2L) e$path else NA_character_
  }, character(1))
  paths <- paths[!is.na(paths)]

  scheme <- sub("://.*", "", dir_path)
  bucket <- sub("^[^/]+/", "", sub("^(gs|s3)://", "", dir_path))
  bucket_prefix <- sub("/.*", "", sub("^(gs|s3)://", "", dir_path))
  paths <- paste0(scheme, "://", paths)

  if (!is.null(pattern)) {
    paths <- paths[grepl(pattern, basename(paths))]
  }
  paths
}


#' Create a local directory (no-op for cloud paths)
#'
#' Cloud object stores do not have directories; they are implied by
#' object key prefixes. This function calls [base::dir.create()] for
#' local paths and does nothing for cloud URIs.
#'
#' @param path Character scalar. A directory path or URI.
#'
#' @returns `NULL` (invisibly).
#'
#' @keywords internal
ensure_dir <- function(path) {
  if (is_cloud_path(path)) return(invisible(NULL))
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(NULL)
}
