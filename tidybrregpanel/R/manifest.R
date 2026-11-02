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
#' @seealso [brreg_snapshot()] to create snapshots,
#'   [brreg_snapshots()] to list them.
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
      raw_path = character(), parquet_path = character(),
      cdc_bridge_first_update_id = integer()
    ))
  }
  entries <- jsonlite::fromJSON(path, simplifyVector = FALSE)$downloads
  if (length(entries) == 0) return(brreg_manifest())
  dplyr::bind_rows(lapply(entries, function(e) {
    safe_chr <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else as.character(x)
    safe_int <- function(x) if (is.null(x) || length(x) == 0) NA_integer_ else as.integer(x)
    tibble::tibble(
      id                 = safe_chr(e$id),
      type               = safe_chr(e$type),
      snapshot_date      = as.Date(safe_chr(e$snapshot_date)),
      endpoint           = safe_chr(e$endpoint),
      format             = safe_chr(e$format),
      download_timestamp = as.POSIXct(safe_chr(e$download_timestamp)),
      last_modified      = safe_chr(e$last_modified),
      etag               = safe_chr(e$etag),
      file_hash          = safe_chr(e$file_hash),
      record_count       = safe_int(e$record_count),
      raw_path           = safe_chr(e$raw_path),
      parquet_path       = safe_chr(e$parquet_path),
      cdc_bridge_first_update_id = safe_int(e$cdc_bridge_first_update_id)
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
                                  parquet_path = NULL, record_count = NULL,
                                  cdc_bridge_first_update_id = NULL) {
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
    parquet_path       = parquet_path,
    cdc_bridge_first_update_id = cdc_bridge_first_update_id
  )
  entry
}
