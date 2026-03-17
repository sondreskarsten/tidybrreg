#' Check availability of local bulk datasets
#'
#' Inspects the snapshot store and download cache for each requested
#' dataset type. Used internally by [brreg_network()] to gate
#' depth > 1 operations that require local data for person-to-entity
#' reverse lookups.
#'
#' @param datasets Character vector of dataset types to check.
#' @param quiet Logical. If `TRUE`, suppress informational messages.
#'
#' @returns A list with components: `available` (character vector of
#'   datasets found locally), `missing` (character vector of datasets
#'   not found), `all_ready` (logical).
#'
#' @family tidybrreg data management functions
#' @seealso [brreg_snapshot()] to download and cache bulk data,
#'   [brreg_download()] for one-off downloads.
#'
#' @export
#' @examples
#' brreg_status()
brreg_status <- function(datasets = c("enheter", "underenheter", "roller"),
                          quiet = FALSE) {
  datasets <- match.arg(datasets, several.ok = TRUE)
  found <- vapply(datasets, has_bulk_data, logical(1))

  if (!quiet) {
    for (ds in datasets) {
      if (found[ds]) {
        src <- bulk_data_source(ds)
        cli::cli_alert_success("{ds}: available ({src})")
      } else {
        cli::cli_alert_danger("{ds}: not available")
      }
    }
  }

  list(
    available = datasets[found],
    missing   = datasets[!found],
    all_ready = all(found)
  )
}


has_bulk_data <- function(type) {
  nrow(brreg_snapshots(type)) > 0 || has_cached_download(type)
}


has_cached_download <- function(type) {
  cache_dir <- tools::R_user_dir("tidybrreg", "cache")
  ext <- if (type == "roller") "json" else "csv"
  file.exists(file.path(cache_dir, paste0(type, "_bulk.", ext, ".gz")))
}


bulk_data_source <- function(type) {
  snaps <- brreg_snapshots(type)
  if (nrow(snaps) > 0) {
    latest <- max(snaps$snapshot_date)
    return(paste0("snapshot ", latest))
  }
  if (has_cached_download(type)) return("download cache")
  "none"
}


require_bulk_data <- function(datasets = c("enheter", "underenheter", "roller"),
                               call = rlang::caller_env()) {
  status <- brreg_status(datasets, quiet = TRUE)
  if (status$all_ready) return(invisible(status))

  sizes <- c(enheter = "~152 MB", underenheter = "~59 MB", roller = "~131 MB")
  total_mb <- sum(c(enheter = 152, underenheter = 59, roller = 131)[status$missing])
  items <- paste0(status$missing, " (", sizes[status$missing], ")")

  if (rlang::is_interactive()) {
    cli::cli_inform(c(
      "!" = "Missing bulk data: {.val {items}}",
      "i" = "Total download: ~{total_mb} MB"
    ))
    ans <- utils::askYesNo("Download now?")
    if (isTRUE(ans)) {
      for (ds in status$missing) {
        brreg_snapshot(type = ds, ask = FALSE)
      }
      return(invisible(brreg_status(datasets, quiet = TRUE)))
    }
  }

  cli::cli_abort(c(
    "Bulk data required but not available: {.val {status$missing}}.",
    "i" = "Download with:",
    " " = "{.code brreg_snapshot()}",
    " " = "{.code brreg_snapshot(type = \"underenheter\")}",
    " " = "{.code brreg_snapshot(type = \"roller\")}"
  ), call = call)
}


#' Resolve local bulk data for network expansion
#'
#' Returns the latest available data for each type, preferring
#' parquet snapshots (fast, pre-parsed) over download cache
#' (raw, requires re-parsing). With arrow installed, returns
#' Arrow Tables for lazy filtered reads (zero-copy memory map).
#' Results are cached in the session environment so repeated
#' calls within the same R session do not re-read from disk.
#'
#' @param types Character vector of types to resolve.
#' @returns Named list of tibbles (or Arrow Tables).
#' @keywords internal
resolve_bulk_data <- function(types = c("enheter", "underenheter", "roller")) {
  stats::setNames(lapply(types, resolve_bulk), types)
}


#' Resolve a single bulk dataset with session caching
#'
#' Resolution order:
#' 1. Session cache in `.brregEnv` (keyed by type + snapshot date)
#' 2. Parquet snapshot — Arrow Table if arrow installed, else tibble
#' 3. Download cache — raw JSON/CSV parsed to tibble
#'
#' Arrow Tables are zero-copy memory maps (~0 bytes until filtered).
#' Tibbles from nanoparquet or raw cache load the full dataset eagerly
#' (~2 GB for roller, ~1.5 GB for enheter).
#'
#' @param type One of `"enheter"`, `"underenheter"`, `"roller"`.
#' @returns An Arrow Table, tibble, or NULL if not available.
#' @keywords internal
resolve_bulk <- function(type) {
  snaps <- brreg_snapshots(type)
  use_arrow <- requireNamespace("arrow", quietly = TRUE)

  if (nrow(snaps) > 0) {
    latest_date <- max(snaps$snapshot_date)
    cache_key <- paste0("bulk_", type, "_", latest_date)

    if (exists(cache_key, envir = .brregEnv)) {
      return(get(cache_key, envir = .brregEnv))
    }

    latest_path <- snaps$path[which.max(snaps$snapshot_date)]
    result <- if (use_arrow) {
      arrow::read_parquet(latest_path, as_data_frame = FALSE)
    } else {
      read_parquet_safe(latest_path)
    }
    assign(cache_key, result, envir = .brregEnv)
    return(result)
  }

  cache_key_dl <- paste0("bulk_dl_", type)
  if (exists(cache_key_dl, envir = .brregEnv)) {
    return(get(cache_key_dl, envir = .brregEnv))
  }

  cache_dir <- tools::R_user_dir("tidybrreg", "cache")
  ext <- if (type == "roller") "json" else "csv"
  cache_file <- file.path(cache_dir, paste0(type, "_bulk.", ext, ".gz"))
  if (file.exists(cache_file)) {
    result <- if (type == "roller") {
      parse_roles_bulk(cache_file)
    } else {
      parse_bulk_csv(cache_file, type = type)
    }
    assign(cache_key_dl, result, envir = .brregEnv)
    return(result)
  }

  NULL
}


#' Filter bulk data by column values
#'
#' Dispatches to Arrow pushdown filter or base R subsetting
#' depending on the object type. Arrow path reads only matching
#' row groups from disk; base R path scans the full in-memory tibble.
#'
#' @param data An Arrow Table or tibble.
#' @param col Column name to filter on.
#' @param values Character vector of values to match.
#' @param select Optional character vector of columns to keep.
#' @returns A tibble (always materialized).
#' @keywords internal
filter_bulk <- function(data, col, values, select = NULL) {
  if (inherits(data, "ArrowObject")) {
    q <- data |> dplyr::filter(.data[[col]] %in% values)
    if (!is.null(select)) q <- q |> dplyr::select(dplyr::any_of(select))
    dplyr::collect(q)
  } else {
    rows <- data[[col]] %in% values
    out <- data[rows, , drop = FALSE]
    if (!is.null(select)) {
      keep <- intersect(select, names(out))
      out <- out[, keep, drop = FALSE]
    }
    out
  }
}
