#' Save a dated snapshot of the full register
#'
#' Download today's complete register and save as a Parquet partition
#' in the local snapshot store. Each call adds one partition to a
#' Hive-partitioned dataset at
#' `tools::R_user_dir("tidybrreg", "data")/{type}/snapshot_date={date}/`.
#' Subsequent calls to [brreg_panel()] and [brreg_events()] query this
#' partitioned dataset lazily via `arrow::open_dataset()`.
#'
#' @param type One of `"enheter"` (main entities, default),
#'   `"underenheter"` (sub-entities / establishments), or
#'   `"roller"` (all roles for all entities, via
#'   `/roller/totalbestand`). Roller snapshots parse the nested
#'   JSON into a flat tibble matching [brreg_roles()] output.
#' @param format Download format: `"csv"` (default for enheter/underenheter)
#'   or `"json"`. JSON captures additional fields not present in CSV
#'   (e.g. `kapital`, `vedtektsfestetFormaal`, `paategninger`).
#'   Roller is always JSON regardless of this parameter.
#' @param date Date for this snapshot (default: today). Used as the
#'   partition key, not as an API parameter — the brreg bulk endpoint
#'   always returns the current-day state.
#' @param force Logical. If `TRUE`, overwrite an existing partition for
#'   this date. Default `FALSE` skips if partition exists.
#' @param ask Logical. If `TRUE` (the default in interactive sessions),
#'   prompt before downloading ~145 MB.
#'
#' @returns The file path to the written Parquet partition (invisibly).
#'
#' @family tidybrreg snapshot functions
#' @seealso [brreg_import()] to add historical snapshots from CSV files,
#'   [brreg_snapshots()] to list available snapshots,
#'   [brreg_panel()] to construct panels from accumulated snapshots.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet() && tidybrreg:::parquet_tier() != "none"
#' \donttest{
#' brreg_snapshot()
#' brreg_snapshots()
#' }
brreg_snapshot <- function(type = c("enheter", "underenheter", "roller"),
                            format = c("csv", "json"),
                            date = Sys.Date(),
                            force = FALSE,
                            ask = interactive()) {
  type <- match.arg(type)
  format <- match.arg(format)
  check_parquet_available()
  date <- as.Date(date)

  if (type == "roller") format <- "json"

  partition_dir <- file.path(brreg_data_dir(), type,
                              paste0("snapshot_date=", date))
  parquet_path <- file.path(partition_dir, "data.parquet")

  if (file.exists(parquet_path) && !force) {
    cli::cli_alert_info("Snapshot for {date} already exists. Use {.arg force = TRUE} to overwrite.")
    return(invisible(parquet_path))
  }

  sizes <- c(enheter = "~152 MB", underenheter = "~59 MB", roller = "~131 MB")
  if (ask && !isTRUE(getOption("brreg.allow_download"))) {
    msg <- paste0("Download full ", type, " register (", sizes[type], ", ", format, ") and save snapshot for ", date, "?")
    if (!isTRUE(utils::askYesNo(msg))) {
      cli::cli_abort("Cancelled by user.")
    }
  }

  raw_cache <- brreg_download(type = type, format = format, type_output = "path", refresh = TRUE)

  raw_dir <- file.path(partition_dir, "raw")
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  raw_dest <- file.path(raw_dir, basename(raw_cache))
  file.copy(raw_cache, raw_dest, overwrite = TRUE)

  dat <- if (type == "roller") {
    parse_roles_bulk(raw_cache)
  } else if (format == "json") {
    parse_bulk_json(raw_cache, type = type)
  } else {
    parse_bulk_csv(raw_cache, type = type)
  }
  write_parquet_safe(dat, parquet_path)

  resp <- tryCatch(get("last_download_resp", envir = .brregEnv), error = \(e) NULL)
  url <- tryCatch(get("last_download_url", envir = .brregEnv), error = \(e) NA_character_)
  entry <- build_manifest_entry(
    type = type, snapshot_date = date,
    endpoint = url, format = format,
    resp = resp, raw_path = raw_dest,
    parquet_path = parquet_path, record_count = nrow(dat)
  )
  write_manifest_entry(entry)

  fsize <- file.size(parquet_path)
  n_label <- if (type == "roller") "role records" else "entities"
  cli::cli_alert_success("Snapshot saved: {date} ({round(fsize / 1024^2, 1)} MB, {nrow(dat)} {n_label})")
  invisible(parquet_path)
}


#' Import a historical CSV as a snapshot partition
#'
#' Read a brreg bulk CSV file (as downloaded by [brreg_download()] or
#' from the brreg website), normalize column names via [field_dict],
#' and save as a dated Parquet partition in the snapshot store.
#'
#' @param path Path to a brreg CSV file (gzipped or plain).
#' @param snapshot_date The date this CSV represents. Required — the
#'   CSV itself contains no date metadata.
#' @param type One of `"enheter"` or `"underenheter"`.
#' @param force Logical. Overwrite existing partition.
#'
#' @returns The file path to the written Parquet partition (invisibly).
#'
#' @family tidybrreg snapshot functions
#' @seealso [brreg_snapshot()] to download and save today's register.
#'
#' @export
#' @examplesIf FALSE
#' # Import a historical download
#' brreg_import("enheter_2024-12-31.csv.gz", snapshot_date = "2024-12-31")
brreg_import <- function(path, snapshot_date,
                          type = c("enheter", "underenheter", "roller"),
                          force = FALSE) {
  type <- match.arg(type)
  check_parquet_available()
  snapshot_date <- as.Date(snapshot_date)

  partition_dir <- file.path(brreg_data_dir(), type,
                              paste0("snapshot_date=", snapshot_date))
  parquet_path <- file.path(partition_dir, "data.parquet")

  if (file.exists(parquet_path) && !force) {
    cli::cli_alert_info("Snapshot for {snapshot_date} already exists. Use {.arg force = TRUE} to overwrite.")
    return(invisible(parquet_path))
  }

  dat <- parse_bulk_csv(path, type = type)
  write_parquet_safe(dat, parquet_path)

  fsize <- file.size(parquet_path)
  cli::cli_alert_success("Imported: {snapshot_date} ({round(fsize / 1024^2, 1)} MB, {nrow(dat)} rows)")
  invisible(parquet_path)
}


#' List available snapshots
#'
#' Scan the local snapshot store and return metadata for each partition.
#'
#' @param type One of `"enheter"` or `"underenheter"`.
#'
#' @returns A tibble with columns: `snapshot_date` (Date), `file_size`
#'   (numeric, bytes), `path` (character).
#'
#' @family tidybrreg snapshot functions
#' @export
#' @examples
#' brreg_snapshots()
brreg_snapshots <- function(type = c("enheter", "underenheter", "roller")) {
  type <- match.arg(type)
  base <- file.path(brreg_data_dir(), type)
  if (!dir.exists(base)) {
    return(tibble::tibble(
      snapshot_date = as.Date(character()),
      file_size = numeric(),
      path = character()
    ))
  }

  dirs <- list.dirs(base, recursive = FALSE, full.names = TRUE)
  dates <- sub("^snapshot_date=", "", basename(dirs))
  valid <- !is.na(suppressWarnings(as.Date(dates)))
  dirs <- dirs[valid]
  dates <- as.Date(dates[valid])

  files <- file.path(dirs, "data.parquet")
  exists <- file.exists(files)

  tibble::tibble(
    snapshot_date = dates[exists],
    file_size = file.size(files[exists]),
    path = files[exists]
  ) |>
    dplyr::arrange(.data$snapshot_date)
}


#' Path to the tidybrreg data store
#'
#' Returns (and creates if needed) the root directory where tidybrreg
#' stores Parquet snapshots, sync state, and changelog files.
#'
#' By default uses R's standard user data directory via
#' `tools::R_user_dir("tidybrreg", "data")`. Override with
#' `options(brreg.data_dir = "/custom/path")`.
#'
#' Supports cloud storage URIs (`gs://`, `s3://`) when \pkg{arrow}
#' is installed with the corresponding backend compiled in. Cloud
#' paths skip local directory creation — object stores use key
#' prefixes rather than explicit directories.
#'
#' @returns Character path or URI.
#'
#' @family tidybrreg snapshot functions
#' @export
#' @examples
#' brreg_data_dir()
#'
#' \dontrun{
#' # Use Google Cloud Storage as the data store
#' options(brreg.data_dir = "gs://my-bucket/tidybrreg")
#' brreg_data_dir()
#'
#' # Use S3-compatible storage
#' options(brreg.data_dir = "s3://my-bucket/tidybrreg")
#' brreg_data_dir()
#' }
brreg_data_dir <- function() {
  dir <- getOption("brreg.data_dir", tools::R_user_dir("tidybrreg", "data"))
  if (is_cloud_path(dir)) {
    check_cloud_arrow(dir)
  } else {
    if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}


#' Remove old snapshots from the local store
#'
#' Delete snapshot partitions by count or age. At least one of
#' `keep_n` or `max_age_days` must be provided.
#'
#' @param keep_n Integer. Keep the `keep_n` most recent snapshots and
#'   delete the rest. `NULL` to skip this criterion.
#' @param max_age_days Integer. Delete snapshots older than this many
#'   days. `NULL` to skip this criterion.
#' @param type One of `"enheter"` or `"underenheter"`.
#'
#' @returns A tibble of deleted snapshots (invisibly).
#'
#' @family tidybrreg snapshot functions
#' @export
#' @examplesIf FALSE
#' brreg_cleanup(keep_n = 12)
#' brreg_cleanup(max_age_days = 365)
brreg_cleanup <- function(keep_n = NULL, max_age_days = NULL,
                           type = c("enheter", "underenheter", "roller")) {
  type <- match.arg(type)
  if (is.null(keep_n) && is.null(max_age_days)) {
    cli::cli_abort("Provide at least one of {.arg keep_n} or {.arg max_age_days}.")
  }

  snaps <- brreg_snapshots(type)
  if (nrow(snaps) == 0) return(invisible(snaps))

  to_delete <- rep(FALSE, nrow(snaps))

  if (!is.null(max_age_days)) {
    cutoff <- Sys.Date() - max_age_days
    to_delete <- to_delete | (snaps$snapshot_date < cutoff)
  }
  if (!is.null(keep_n)) {
    if (keep_n < nrow(snaps)) {
      ranked <- order(snaps$snapshot_date, decreasing = TRUE)
      excess <- ranked[seq(keep_n + 1, nrow(snaps))]
      to_delete[excess] <- TRUE
    }
  }

  deleted <- snaps[to_delete, ]
  if (nrow(deleted) > 0) {
    for (p in deleted$path) unlink(dirname(p), recursive = TRUE)
    cli::cli_alert_success("Deleted {nrow(deleted)} snapshot{?s}.")
  }
  invisible(deleted)
}


#' Open the snapshot store as a lazy Arrow Dataset
#'
#' Returns an Arrow Dataset with Hive-style partitioning on
#' `snapshot_date`. No data is loaded until `dplyr::collect()`.
#' Requires the arrow package.
#'
#' @param type One of `"enheter"` or `"underenheter"`.
#'
#' @returns An `arrow::Dataset` object.
#'
#' @family tidybrreg snapshot functions
#' @seealso [brreg_panel()] for the higher-level panel constructor.
#'
#' @export
#' @examplesIf interactive() && requireNamespace("arrow", quietly = TRUE)
#' ds <- brreg_open()
#' ds
brreg_open <- function(type = c("enheter", "underenheter", "roller")) {
  type <- match.arg(type)
  rlang::check_installed("arrow", reason = "for lazy dataset queries over snapshots.")
  base <- file.path(brreg_data_dir(), type)
  if (!dir.exists(base) || length(list.dirs(base, recursive = FALSE)) == 0) {
    cli::cli_abort(c(
      "No snapshots found for {.val {type}}.",
      "i" = "Run {.code brreg_snapshot()} to save one."
    ))
  }
  arrow::open_dataset(base, partitioning = arrow::hive_partition(snapshot_date = arrow::date32()))
}
