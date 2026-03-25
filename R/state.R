#' Path to the sync state directory
#'
#' Returns `brreg_data_dir()/state/`. Contains live state parquets,
#' the sync cursor, and the Hive-partitioned changelog. On cloud
#' URIs the directory is virtual (implied by object key prefix).
#'
#' @returns Character path or URI.
#' @keywords internal
state_dir <- function() {
  d <- file.path(brreg_data_dir(), "state")
  ensure_dir(d)
  d
}


#' Path to the changelog directory
#'
#' Returns `state_dir()/changelog/`. Changelog entries are
#' Hive-partitioned by `sync_date`.
#'
#' @returns Character path or URI.
#' @keywords internal
changelog_dir <- function() {
  d <- file.path(state_dir(), "changelog")
  ensure_dir(d)
  d
}


#' Read current state for a registry type
#'
#' Loads state from parquet, caching in `.brregEnv` for the session.
#' Returns `NULL` if no state file exists. Works transparently on
#' local paths and cloud URIs.
#'
#' @param type One of `"enheter"`, `"underenheter"`, `"roller"`,
#'   `"paategninger"`.
#' @param use_cache Logical. Use session cache if available.
#'
#' @returns A tibble or `NULL`.
#' @keywords internal
read_state <- function(type, use_cache = TRUE) {
  cache_key <- paste0("state_", type)
  if (use_cache && exists(cache_key, envir = .brregEnv)) {
    return(get(cache_key, envir = .brregEnv))
  }
  path <- file.path(state_dir(), paste0(type, ".parquet"))
  if (!cloud_file_exists(path)) return(NULL)
  df <- read_parquet_safe(path)
  assign(cache_key, df, envir = .brregEnv)
  df
}


#' Write state atomically and update session cache
#'
#' Writes a state tibble to parquet under `state_dir()`. On local
#' paths uses temp-file-and-rename for atomicity. On cloud URIs
#' writes directly (cloud object stores are atomic per-object).
#'
#' @param df A tibble.
#' @param type Registry type.
#'
#' @returns The file path (invisibly).
#' @keywords internal
write_state <- function(df, type) {
  path <- file.path(state_dir(), paste0(type, ".parquet"))
  write_parquet_safe(df, path)
  assign(paste0("state_", type), df, envir = .brregEnv)
  invisible(path)
}


#' Check whether state exists for a given type
#'
#' @param type Registry type string.
#'
#' @returns Logical.
#' @keywords internal
has_state <- function(type) {
  cloud_file_exists(file.path(state_dir(), paste0(type, ".parquet")))
}


#' Read the sync cursor
#'
#' The cursor tracks the last-seen `update_id` for each CDC stream
#' and the last sync timestamp. Stored as a single-row parquet file
#' at `state/sync_cursor.parquet`.
#'
#' On first read after upgrading from v0.3.x, migrates the legacy
#' JSON cursor (`sync_cursor.json`) to parquet automatically. The
#' JSON file is deleted after successful migration. Migration is
#' skipped on cloud paths (no legacy JSON expected).
#'
#' @returns A list with `enheter_id` (integer), `underenheter_id`
#'   (integer), `roller_id` (integer), `last_sync` (character ISO
#'   timestamp or `NA`).
#'
#' @keywords internal
read_cursor <- function() {
  defaults <- list(
    enheter_id = 0L, underenheter_id = 0L,
    roller_id = 0L, last_sync = NA_character_
  )

  parquet_path <- file.path(state_dir(), "sync_cursor.parquet")
  if (cloud_file_exists(parquet_path)) {
    df <- read_parquet_safe(parquet_path)
    return(list(
      enheter_id      = as.integer(df$enheter_id[1]),
      underenheter_id = as.integer(df$underenheter_id[1]),
      roller_id       = as.integer(df$roller_id[1]),
      last_sync       = as.character(df$last_sync[1])
    ))
  }

  json_path <- file.path(state_dir(), "sync_cursor.json")
  if (!is_cloud_path(state_dir()) && file.exists(json_path)) {
    cursor <- jsonlite::fromJSON(json_path)
    write_cursor(cursor)
    unlink(json_path)
    return(cursor)
  }

  defaults
}


#' Write the sync cursor
#'
#' Stores cursor positions as a single-row parquet file. The
#' `last_sync` field is set to the current time automatically.
#'
#' @param cursor A list with `enheter_id`, `underenheter_id`,
#'   `roller_id` (integer cursor positions).
#'
#' @returns The file path (invisibly).
#' @keywords internal
write_cursor <- function(cursor) {
  cursor$last_sync <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  path <- file.path(state_dir(), "sync_cursor.parquet")
  cursor_df <- tibble::tibble(
    enheter_id      = as.integer(cursor$enheter_id %||% 0L),
    underenheter_id = as.integer(cursor$underenheter_id %||% 0L),
    roller_id       = as.integer(cursor$roller_id %||% 0L),
    last_sync       = as.character(cursor$last_sync)
  )
  write_parquet_safe(cursor_df, path)
  invisible(path)
}


#' Append changelog entries to the Hive-partitioned store
#'
#' Writes one parquet file per sync batch under
#' `changelog/sync_date={date}/batch-{time}.parquet`. Works on
#' local paths and cloud URIs.
#'
#' @param changes A tibble with changelog rows matching the schema
#'   returned by [empty_changelog()].
#' @param sync_date Date for the partition key. Defaults to today.
#'
#' @returns The written file path (invisibly), or `NULL` if
#'   `changes` is empty.
#' @keywords internal
write_changelog <- function(changes, sync_date = Sys.Date()) {
  if (is.null(changes) || nrow(changes) == 0) return(invisible(NULL))
  partition <- file.path(changelog_dir(),
                          paste0("sync_date=", sync_date))
  ensure_dir(partition)
  fname <- sprintf("batch-%s.parquet", format(Sys.time(), "%H%M%S"))
  path <- file.path(partition, fname)
  write_parquet_safe(changes, path)
  invisible(path)
}


#' Read changelog entries
#'
#' Reads all or filtered changelog partitions. Uses
#' [arrow::open_dataset()] when available for partition pruning;
#' required for cloud URIs. Falls back to reading individual
#' parquet files on local paths when only \pkg{nanoparquet} is
#' installed.
#'
#' @param from,to Optional date bounds (character or Date).
#' @param registry Optional filter: `"enheter"`, `"underenheter"`,
#'   `"roller"`, `"paategninger"`.
#' @param change_type Optional filter: `"entry"`, `"exit"`,
#'   `"change"`, `"annotation"`.
#'
#' @returns A tibble of changelog rows.
#'
#' @family tidybrreg data management functions
#' @keywords internal
read_changelog <- function(from = NULL, to = NULL,
                            registry = NULL, change_type = NULL) {
  cl_dir <- changelog_dir()

  use_arrow <- is_cloud_path(cl_dir) ||
    (parquet_tier() == "arrow" && requireNamespace("arrow", quietly = TRUE))

  if (use_arrow) {
    if (is_cloud_path(cl_dir)) check_cloud_arrow(cl_dir)
    ds <- tryCatch(
      arrow::open_dataset(cl_dir, partitioning = "sync_date"),
      error = function(e) {
        if (is_cloud_path(cl_dir)) stop(e)
        NULL
      }
    )
    if (!is.null(ds)) {
      q <- ds
      if (!is.null(from)) q <- dplyr::filter(q, sync_date >= from)
      if (!is.null(to)) q <- dplyr::filter(q, sync_date <= to)
      if (!is.null(registry))
        q <- dplyr::filter(q, .data$registry %in% .env$registry)
      if (!is.null(change_type))
        q <- dplyr::filter(q, .data$change_type %in% .env$change_type)
      return(tibble::as_tibble(dplyr::collect(q)))
    }
  }

  partitions <- list.dirs(cl_dir, recursive = FALSE, full.names = TRUE)
  if (length(partitions) == 0) return(empty_changelog())

  dates <- sub("^sync_date=", "", basename(partitions))
  keep <- rep(TRUE, length(dates))
  if (!is.null(from)) keep <- keep & dates >= as.character(from)
  if (!is.null(to)) keep <- keep & dates <= as.character(to)
  partitions <- partitions[keep]

  all_files <- unlist(lapply(partitions, function(p) {
    list.files(p, pattern = "\\.parquet$", full.names = TRUE)
  }))
  if (length(all_files) == 0) return(empty_changelog())

  result <- dplyr::bind_rows(lapply(all_files, read_parquet_safe))
  if (!is.null(registry)) result <- result[result$registry %in% registry, ]
  if (!is.null(change_type)) result <- result[result$change_type %in% change_type, ]
  result
}


#' Empty changelog tibble with correct schema
#' @returns A zero-row tibble with the changelog column spec.
#' @keywords internal
empty_changelog <- function() {
  tibble::tibble(
    timestamp   = character(),
    org_nr      = character(),
    registry    = character(),
    change_type = character(),
    field       = character(),
    value_from  = character(),
    value_to    = character(),
    update_id   = integer()
  )
}


#' Display sync status
#'
#' Shows the current state of the sync engine: which state files
#' exist, when the last sync occurred, cursor positions, and
#' changelog size. Works on both local and cloud storage backends.
#'
#' @returns A list with status components (invisibly).
#'
#' @family tidybrreg data management functions
#' @export
#' @examples
#' brreg_sync_status()
brreg_sync_status <- function() {
  cursor <- read_cursor()
  types <- c("enheter", "underenheter", "roller", "paategninger")

  state_info <- lapply(types, function(t) {
    path <- file.path(state_dir(), paste0(t, ".parquet"))
    info <- cloud_file_info(path)
    if (info$exists) {
      list(exists = TRUE,
           size_mb = round(info$size / 1024 / 1024, 1),
           modified = if (!is.na(info$mtime)) format(info$mtime, "%Y-%m-%d %H:%M") else NA_character_)
    } else {
      list(exists = FALSE, size_mb = 0, modified = NA_character_)
    }
  })
  names(state_info) <- types

  cl_dir <- changelog_dir()
  cl_files <- tryCatch(
    cloud_list_files(cl_dir, pattern = "\\.parquet$", recursive = TRUE),
    error = function(e) character()
  )
  cl_dates <- unique(
    sub(".*/sync_date=([^/]+)/.*", "\\1",
        cl_files[grepl("sync_date=", cl_files)])
  )

  cli::cli_h2("tidybrreg sync status")
  if (is_cloud_path(brreg_data_dir())) {
    cli::cli_text("Backend: {.url {brreg_data_dir()}}")
  }

  cli::cli_text("Last sync: {cursor$last_sync %||% 'never'}")
  cli::cli_text("Cursor positions: enheter={cursor$enheter_id}, underenheter={cursor$underenheter_id}, roller={cursor$roller_id}")

  for (t in types) {
    info <- state_info[[t]]
    if (info$exists) {
      cli::cli_alert_success("{t}: {info$size_mb} MB (updated {info$modified})")
    } else {
      cli::cli_alert_warning("{t}: not initialized")
    }
  }

  cli::cli_text("Changelog: {length(cl_dates)} partition(s), {length(cl_files)} file(s)")

  invisible(list(cursor = cursor, state = state_info,
                  changelog_partitions = length(cl_dates)))
}
