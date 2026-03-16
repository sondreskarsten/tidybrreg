#' Read the snapshot manifest
#'
#' Returns the provenance catalog recording every download: endpoint,
#' timestamps, HTTP headers, file hashes, and CDC bridge metadata.
#' The manifest lives at `brreg_data_dir()/manifest.json`.
#'
#' @returns A tibble with one row per snapshot. Returns an empty tibble
#'   if no manifest exists.
#'
#' @family tidybrreg snapshot functions
#' @export
#' @examples
#' brreg_manifest()
brreg_manifest <- function() {
  path <- manifest_path()
  if (!file.exists(path)) {
    return(tibble::tibble(
      id = character(), type = character(), snapshot_date = as.Date(character()),
      endpoint = character(), format = character(),
      download_timestamp = as.POSIXct(character()),
      last_modified = character(), etag = character(),
      file_hash = character(), record_count = integer(),
      raw_path = character(), parquet_path = character()
    ))
  }
  entries <- jsonlite::fromJSON(path, simplifyVector = FALSE)$downloads
  if (length(entries) == 0) return(brreg_manifest())
  dplyr::bind_rows(lapply(entries, function(e) {
    tibble::tibble(
      id                 = e$id %||% NA_character_,
      type               = e$type %||% NA_character_,
      snapshot_date      = as.Date(e$snapshot_date %||% NA_character_),
      endpoint           = e$endpoint %||% NA_character_,
      format             = e$format %||% NA_character_,
      download_timestamp = as.POSIXct(e$download_timestamp %||% NA_character_),
      last_modified      = e$last_modified %||% NA_character_,
      etag               = e$etag %||% NA_character_,
      file_hash          = e$file_hash %||% NA_character_,
      record_count       = as.integer(e$record_count %||% NA),
      raw_path           = e$raw_path %||% NA_character_,
      parquet_path       = e$parquet_path %||% NA_character_
    )
  }))
}


#' Path to the manifest file
#' @keywords internal
manifest_path <- function() {
  file.path(brreg_data_dir(), "manifest.json")
}


#' Append an entry to the manifest
#' @param entry Named list with manifest fields.
#' @keywords internal
write_manifest_entry <- function(entry) {
  path <- manifest_path()
  if (file.exists(path)) {
    manifest <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  } else {
    manifest <- list(schema_version = "1.0", downloads = list())
  }
  manifest$downloads <- c(manifest$downloads, list(entry))
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE)
}


#' Build a manifest entry from download metadata
#' @keywords internal
build_manifest_entry <- function(type, snapshot_date, endpoint, format,
                                  resp = NULL, raw_path = NULL,
                                  parquet_path = NULL, record_count = NULL) {
  entry <- list(
    id                 = paste0(type, "_", snapshot_date),
    type               = type,
    snapshot_date      = as.character(snapshot_date),
    endpoint           = endpoint,
    format             = format,
    download_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
    last_modified      = if (!is.null(resp)) httr2::resp_header(resp, "Last-Modified") else NA_character_,
    etag               = if (!is.null(resp)) httr2::resp_header(resp, "ETag") else NA_character_,
    file_hash          = if (!is.null(raw_path) && file.exists(raw_path)) rlang::hash_file(raw_path) else NA_character_,
    record_count       = record_count,
    raw_path           = raw_path,
    parquet_path       = parquet_path
  )
  entry
}
