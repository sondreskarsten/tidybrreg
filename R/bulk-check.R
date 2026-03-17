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
#' (raw, requires re-parsing). For roller data with arrow
#' available, returns an Arrow Table for lazy filtering.
#'
#' @param types Character vector of types to resolve.
#' @returns Named list of tibbles (or Arrow Tables).
#' @keywords internal
resolve_bulk_data <- function(types = c("enheter", "underenheter", "roller")) {
  result <- stats::setNames(vector("list", length(types)), types)

  for (type in types) {
    snaps <- brreg_snapshots(type)
    if (nrow(snaps) > 0) {
      latest_path <- snaps$path[which.max(snaps$snapshot_date)]
      if (type == "roller" && requireNamespace("arrow", quietly = TRUE)) {
        result[[type]] <- arrow::read_parquet(latest_path, as_data_frame = FALSE)
      } else {
        result[[type]] <- read_parquet_safe(latest_path)
      }
      next
    }

    cache_dir <- tools::R_user_dir("tidybrreg", "cache")
    ext <- if (type == "roller") "json" else "csv"
    cache_file <- file.path(cache_dir, paste0(type, "_bulk.", ext, ".gz"))
    if (file.exists(cache_file)) {
      result[[type]] <- if (type == "roller") {
        parse_roles_bulk(cache_file)
      } else {
        parse_bulk_csv(cache_file, type = type)
      }
      next
    }

    result[[type]] <- NULL
  }

  result
}
