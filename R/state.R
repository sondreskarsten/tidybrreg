#' Path to the sync state directory
#'
#' Returns `brreg_data_dir()/state/`. Contains live state parquets,
#' the sync cursor, and the Hive-partitioned changelog.
#'
#' @returns Character path (created if absent).
#' @keywords internal
state_dir <- function() {
  d <- file.path(brreg_data_dir(), "state")
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}


#' Path to the changelog directory
#' @keywords internal
changelog_dir <- function() {
  d <- file.path(state_dir(), "changelog")
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}


#' Read current state for a registry type
#'
#' Loads state from parquet, caching in `.brregEnv` for the session.
#' Returns `NULL` if no state file exists.
#'
#' @param type One of `"enheter"`, `"underenheter"`, `"roller"`,
#'   `"paategninger"`.
#' @param use_cache Logical. Use session cache if available.
#' @returns A tibble or `NULL`.
#' @keywords internal
read_state <- function(type, use_cache = TRUE) {
  cache_key <- paste0("state_", type)
  if (use_cache && exists(cache_key, envir = .brregEnv)) {
    return(get(cache_key, envir = .brregEnv))
  }
  path <- file.path(state_dir(), paste0(type, ".parquet"))
  if (!file.exists(path)) return(NULL)
  df <- read_parquet_safe(path)
  assign(cache_key, df, envir = .brregEnv)
  df
}


#' Write state atomically and update session cache
#'
#' @param df A tibble.
#' @param type Registry type.
#' @keywords internal
write_state <- function(df, type) {
  path <- file.path(state_dir(), paste0(type, ".parquet"))
  write_parquet_safe(df, path)
  assign(paste0("state_", type), df, envir = .brregEnv)
  invisible(path)
}


#' Check whether state exists for a given type
#' @keywords internal
has_state <- function(type) {
  file.exists(file.path(state_dir(), paste0(type, ".parquet")))
}


#' Read the sync cursor
#'
#' The cursor tracks the last-seen `oppdateringsid` for each CDC
#' stream and the last sync timestamp. Stored as JSON in
#' `state/sync_cursor.json`.
#'
#' @returns A list with `enheter_id`, `underenheter_id`, `roller_id`,
#'   `last_sync`. Returns defaults if no cursor exists.
#' @keywords internal
read_cursor <- function() {
  path <- file.path(state_dir(), "sync_cursor.json")
  if (!file.exists(path)) {
    return(list(
      enheter_id = 0L,
      underenheter_id = 0L,
      roller_id = 0L,
      last_sync = NA_character_
    ))
  }
  jsonlite::fromJSON(path)
}


#' Write the sync cursor atomically
#' @param cursor A list with cursor positions.
#' @keywords internal
write_cursor <- function(cursor) {
  cursor$last_sync <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  path <- file.path(state_dir(), "sync_cursor.json")
  tmp <- tempfile(tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(tmp), add = TRUE)
  jsonlite::write_json(cursor, tmp, auto_unbox = TRUE, pretty = TRUE)
  file.rename(tmp, path)
  invisible(path)
}


#' Append changelog entries to the Hive-partitioned store
#'
#' Writes one parquet file per sync batch under
#' `changelog/sync_date={date}/batch-{time}.parquet`.
#'
#' @param changes A tibble with changelog rows.
#' @param sync_date Date for the partition key.
#' @keywords internal
write_changelog <- function(changes, sync_date = Sys.Date()) {
  if (is.null(changes) || nrow(changes) == 0) return(invisible(NULL))
  partition <- file.path(changelog_dir(),
                          paste0("sync_date=", sync_date))
  dir.create(partition, recursive = TRUE, showWarnings = FALSE)
  fname <- sprintf("batch-%s.parquet", format(Sys.time(), "%H%M%S"))
  path <- file.path(partition, fname)
  write_parquet_safe(changes, path)
  invisible(path)
}


#' Read changelog entries
#'
#' Reads all or filtered changelog partitions. Uses
#' `arrow::open_dataset()` when available for partition pruning,
#' falls back to reading individual parquet files.
#'
#' @param from,to Optional date bounds.
#' @param registry Optional filter: `"enheter"`, `"underenheter"`,
#'   `"roller"`, `"paategninger"`.
#' @param change_type Optional filter: `"entry"`, `"exit"`,
#'   `"change"`, `"annotation"`.
#' @returns A tibble of changelog rows.
#'
#' @family tidybrreg data management functions
#' @keywords internal
read_changelog <- function(from = NULL, to = NULL,
                            registry = NULL, change_type = NULL) {
  cl_dir <- changelog_dir()
  partitions <- list.dirs(cl_dir, recursive = FALSE, full.names = TRUE)
  if (length(partitions) == 0) return(empty_changelog())

  if (parquet_tier() == "arrow" &&
      requireNamespace("arrow", quietly = TRUE)) {
    ds <- arrow::open_dataset(cl_dir, partitioning = "sync_date")
    q <- ds
    if (!is.null(from)) q <- dplyr::filter(q, sync_date >= from)
    if (!is.null(to)) q <- dplyr::filter(q, sync_date <= to)
    if (!is.null(registry)) q <- dplyr::filter(q, .data$registry %in% .env$registry)
    if (!is.null(change_type)) q <- dplyr::filter(q, .data$change_type %in% .env$change_type)
    result <- dplyr::collect(q)
    return(tibble::as_tibble(result))
  }

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
#' changelog size.
#'
#' @returns A list with status components (invisibly).
#'
#' @family tidybrreg data management functions
#' @seealso [brreg_sync()] to run a sync,
#'   [brreg_changes()] to query the changelog.
#' @export
#' @examples
#' brreg_sync_status()
brreg_sync_status <- function() {
  cursor <- read_cursor()
  types <- c("enheter", "underenheter", "roller", "paategninger")
  state_info <- lapply(types, function(t) {
    path <- file.path(state_dir(), paste0(t, ".parquet"))
    if (file.exists(path)) {
      info <- file.info(path)
      list(exists = TRUE,
           size_mb = round(info$size / 1024 / 1024, 1),
           modified = format(info$mtime, "%Y-%m-%d %H:%M"))
    } else {
      list(exists = FALSE, size_mb = 0, modified = NA_character_)
    }
  })
  names(state_info) <- types

  cl_dir <- changelog_dir()
  cl_partitions <- list.dirs(cl_dir, recursive = FALSE)
  cl_files <- if (length(cl_partitions) > 0) {
    list.files(cl_dir, pattern = "\\.parquet$", recursive = TRUE)
  } else {
    character()
  }

  cli::cli_h2("tidybrreg sync status")

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

  cli::cli_text("Changelog: {length(cl_partitions)} partition(s), {length(cl_files)} file(s)")

  invisible(list(cursor = cursor, state = state_info,
                  changelog_partitions = length(cl_partitions)))
}
