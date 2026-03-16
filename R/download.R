#' Download the full Norwegian business register
#'
#' Download a complete extract of the Central Coordinating Register for
#' Legal Entities (~1 million entities, ~145 MB gzipped). The bulk endpoint
#' does not support server-side filtering — it always returns all entities.
#' Use [brreg_search()] for filtered queries up to 10,000 results, or
#' download the full register here and filter locally.
#'
#' @section Backend routing:
#' The brreg API has two data access paths with fundamentally different
#' characteristics, following the cansim (Statistics Canada) pattern of
#' separate functions for separate access patterns rather than the eurostat
#' pattern of auto-routing within one function:
#'
#' - **[brreg_search()]**: JSON API with server-side filtering. Fast for
#'   small result sets, capped at 10,000. Interactive exploration.
#' - **`brreg_download()`**: Bulk CSV. Always returns the full register.
#'   Appropriate for panel construction, spatial joins, or any analysis
#'   requiring more than 10,000 entities.
#'
#' Results from both paths use the same column names via [field_dict].
#'
#' @section Caching:
#' Downloaded files are cached in `tools::R_user_dir("tidybrreg", "cache")`
#' as gzipped CSV. Use `refresh = TRUE` to force re-download, or
#' `refresh = "auto"` to re-download only if the cached file is older
#' than the latest nightly bulk export (checked via ETag headers, following
#' the cansim `refresh = "auto"` pattern).
#'
#' @param type One of `"enheter"` (main entities, default),
#'   `"underenheter"` (sub-entities / establishments), or
#'   `"roller"` (all roles for all entities). Roller data is only
#'   available as JSON via `/roller/totalbestand` (~131 MB).
#' @param format Download format: `"csv"` (default for enheter/underenheter,
#'   semicolon-delimited) or `"json"` (JSON array). Roller bulk download
#'   is always JSON regardless of this parameter.
#' @param refresh `FALSE` (default): use cached file if available.
#'   `TRUE`: force re-download. `"auto"`: check ETag and re-download
#'   only if server has a newer version.
#' @param cache Logical. If `TRUE` (default), cache downloaded file
#'   persistently.
#' @param type_output One of `"tibble"` (default), `"arrow"` (requires
#'   the arrow package), or `"path"` (returns the file path without
#'   parsing).
#'
#' @returns Depends on `type_output`:
#'   - `"tibble"`: A tibble with ~1 million rows. Column names mapped
#'     via [field_dict].
#'   - `"arrow"`: An Arrow Table (lazy, not loaded into memory).
#'   - `"path"`: Character file path to the cached CSV.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_search()] for filtered API queries,
#'   [brreg_updates()] for incremental changes since a given date.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' # Download full register as tibble (~145MB download, ~1M rows)
#' entities <- brreg_download()
#'
#' # Just get the file path (no parsing)
#' path <- brreg_download(type_output = "path")
#'
#' # Force refresh
#' entities <- brreg_download(refresh = TRUE)
#' }
brreg_download <- function(type = c("enheter", "underenheter", "roller"),
                            format = c("csv", "json"),
                            refresh = FALSE,
                            cache = TRUE,
                            type_output = c("tibble", "arrow", "path")) {
  type <- match.arg(type)
  format <- match.arg(format)
  type_output <- match.arg(type_output)

  if (type == "roller" && format == "csv") {
    format <- "json"
    cli::cli_alert_info("Roller only available as JSON. Using {.val json} format.")
  }

  cache_dir <- tools::R_user_dir("tidybrreg", "cache")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_file <- file.path(cache_dir, paste0(type, "_bulk.", format, ".gz"))
  etag_file <- file.path(cache_dir, paste0(type, "_bulk.", format, ".etag"))

  needs_download <- !file.exists(cache_file) || identical(refresh, TRUE)

  url <- if (type == "roller") {
    paste0(brreg_base_url(), "/roller/totalbestand")
  } else if (format == "json") {
    paste0(brreg_base_url(), "/", type, "/lastned")
  } else {
    paste0(brreg_base_url(), "/", type, "/lastned/", format)
  }

  if (identical(refresh, "auto") && file.exists(cache_file) && file.exists(etag_file)) {
    cached_etag <- readLines(etag_file, n = 1, warn = FALSE)
    server_etag <- tryCatch({
      resp <- httr2::request(url) |>
        httr2::req_method("HEAD") |>
        httr2::req_user_agent("tidybrreg (R package)") |>
        httr2::req_perform()
      httr2::resp_header(resp, "ETag")
    }, error = \(e) NULL)
    if (!is.null(server_etag) && !identical(cached_etag, server_etag)) {
      needs_download <- TRUE
    }
  }

  if (needs_download) {
    cli::cli_alert_info("Downloading full {type} register...")
    resp <- httr2::request(url) |>
      httr2::req_user_agent("tidybrreg (R package)") |>
      httr2::req_perform(path = cache_file)
    etag <- httr2::resp_header(resp, "ETag")
    if (!is.null(etag) && cache) {
      writeLines(etag, etag_file)
    }
    fsize <- file.size(cache_file)
    cli::cli_alert_success("Downloaded {round(fsize / 1024^2, 1)} MB to cache.")
  } else if (file.exists(cache_file)) {
    fsize <- file.size(cache_file)
    mtime <- format(file.mtime(cache_file), "%Y-%m-%d %H:%M")
    cli::cli_alert_info("Using cached file ({round(fsize / 1024^2, 1)} MB, {mtime}).")
  }

  if (identical(type_output, "path")) return(cache_file)

  if (identical(type_output, "arrow")) {
    if (!requireNamespace("arrow", quietly = TRUE)) {
      cli::cli_abort(c(
        "The {.pkg arrow} package is required for {.code type_output = \"arrow\"}.",
        "i" = "Install it with {.code install.packages(\"arrow\")}."
      ))
    }
    if (format == "json" || type == "roller") {
      return(arrow::read_json_arrow(cache_file, as_data_frame = FALSE))
    }
    return(arrow::read_csv_arrow(cache_file,
      as_data_frame = FALSE,
      read_options = arrow::CsvReadOptions$create(encoding = "UTF-8")))
  }

  if (type == "roller") return(parse_roles_bulk(cache_file))
  if (format == "json") return(parse_bulk_json(cache_file, type = type))
  parse_bulk_csv(cache_file, type = type)
}


#' Parse a brreg bulk CSV into a tibble using the field dictionary
#'
#' The bulk CSV uses `;` delimiter with `.` notation for nested fields
#' (e.g. `forretningsadresse.kommune`). This function maps those names
#' to the same English column names as the JSON API via [field_dict].
#'
#' @param path Path to the gzipped CSV file.
#' @param type Entity type for column selection.
#' @param n_max Maximum rows to read (default: all).
#'
#' @returns A tibble with columns mapped via [field_dict].
#' @keywords internal
parse_bulk_csv <- function(path, type = "enheter", n_max = Inf) {
  dat <- readr::read_csv(path,
    locale = readr::locale(encoding = "UTF-8"),
    show_col_types = FALSE, progress = TRUE,
    n_max = n_max,
    col_types = readr::cols(.default = readr::col_character())
  )

  csv_to_english <- stats::setNames(field_dict$col_name, tolower(field_dict$api_path))
  csv_names <- names(dat)

  new_names <- vapply(csv_names, function(cn) {
    lcn <- tolower(cn)
    if (lcn %in% names(csv_to_english)) return(csv_to_english[[lcn]])
    to_snake(cn)
  }, character(1), USE.NAMES = FALSE)

  names(dat) <- new_names

  for (i in seq_len(nrow(field_dict))) {
    col <- field_dict$col_name[i]
    if (!col %in% names(dat)) next
    target <- field_dict$type[i]
    dat[[col]] <- switch(target,
      Date      = as.Date(dat[[col]]),
      integer   = suppressWarnings(as.integer(dat[[col]])),
      logical   = as.logical(dat[[col]]),
      character = dat[[col]],
      dat[[col]]
    )
  }

  dat
}


#' Parse a brreg bulk JSON download into a tibble
#'
#' The `/enheter/lastned` and `/underenheter/lastned` endpoints return
#' gzipped JSON arrays where each element has the same nested structure
#' as a single-entity API response. Uses `jsonlite::fromJSON(flatten = TRUE)`
#' to produce a flat data.frame with dot-notation columns, then renames
#' via [field_dict] — same pipeline as [parse_bulk_csv()].
#'
#' @param path Path to the gzipped JSON file.
#' @param type Entity type (for column context).
#' @returns A tibble with columns mapped via [field_dict].
#' @keywords internal
parse_bulk_json <- function(path, type = "enheter") {
  dat <- jsonlite::fromJSON(path, flatten = TRUE)
  dat <- tibble::as_tibble(dat)

  list_cols <- names(dat)[vapply(dat, is.list, logical(1))]
  for (col in list_cols) {
    dat[[col]] <- vapply(dat[[col]], function(x) {
      if (is.null(x) || length(x) == 0) return(NA_character_)
      if (is.data.frame(x)) return(NA_character_)
      if (is.list(x) && is.null(names(x))) return(NA_character_)
      paste(as.character(unlist(x)), collapse = ", ")
    }, character(1))
  }

  json_to_english <- stats::setNames(field_dict$col_name, tolower(field_dict$api_path))
  json_names <- names(dat)

  new_names <- vapply(json_names, function(cn) {
    lcn <- tolower(cn)
    if (lcn %in% names(json_to_english)) return(json_to_english[[lcn]])
    to_snake(cn)
  }, character(1), USE.NAMES = FALSE)

  names(dat) <- new_names

  for (i in seq_len(nrow(field_dict))) {
    col <- field_dict$col_name[i]
    if (!col %in% names(dat)) next
    target <- field_dict$type[i]
    dat[[col]] <- switch(target,
      Date      = as.Date(as.character(dat[[col]])),
      integer   = suppressWarnings(as.integer(dat[[col]])),
      logical   = as.logical(dat[[col]]),
      character = as.character(dat[[col]]),
      dat[[col]]
    )
  }

  dat
}


#' Parse the roller totalbestand gzipped JSON into a flat tibble
#'
#' The `/roller/totalbestand` endpoint returns a gzipped JSON array where
#' each element is an entity with nested rollegrupper/roller structure,
#' identical to `/enheter/{orgnr}/roller`. This function reads the full
#' file, flattens all entities into one tibble matching [brreg_roles()]
#' output.
#'
#' @param path Path to the gzipped JSON file.
#' @returns A tibble with one row per role assignment.
#' @keywords internal
parse_roles_bulk <- function(path) {
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  all_rows <- vector("list", length(raw))
  for (i in seq_along(raw)) {
    entity <- raw[[i]]
    org_nr <- entity$organisasjonsnummer %||% NA_character_
    all_rows[[i]] <- flatten_roles(entity, org_nr)
  }
  dplyr::bind_rows(all_rows)
}
