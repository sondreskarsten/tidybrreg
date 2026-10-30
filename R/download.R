#' Download the full Norwegian business register
#'
#' Download a complete extract of the Central Coordinating Register for
#' Legal Entities (~1 million entities, ~150 MB gzipped). The bulk endpoint
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
#' - **`brreg_download()`**: Bulk CSV or JSON. Always returns the full
#'   register. Appropriate for any analysis requiring more than 10,000
#'   entities.
#'
#' Results from both paths use the same column names and types via
#' [field_dict]; only observed columns are emitted (see
#' [brreg_entity()]).
#'
#' @section Caching:
#' With `cache = TRUE` (default) the gzipped payload is stored in
#' `tools::R_user_dir("tidybrreg", "cache")` together with a sidecar
#' recording the server's `ETag` and `Last-Modified` validators, and a
#' later call reuses it. `refresh = TRUE` forces a new download.
#' `refresh = "auto"` sends a HEAD request and re-downloads when either
#' validator differs from the sidecar; when the sidecar is missing or the
#' server sends neither validator, nothing can prove the cache current,
#' so it is re-downloaded. With `cache = FALSE` the payload goes to a
#' temporary file that is deleted after parsing; with
#' `type_output = "path"` that temporary path is returned and the caller
#' owns it. The cache directory is created only by this function, never
#' at load time.
#'
#' Metadata of the most recent download (`url`, `etag`, `last_modified`
#' as a UTC `POSIXct`, `downloaded_at`, `path`) is available as
#' `attr(result, "brreg_download")` on tibble output.
#'
#' @param type One of `"enheter"` (main entities, default),
#'   `"underenheter"` (sub-entities / establishments), or
#'   `"roller"` (all roles for all entities). Roller data is only
#'   available as JSON via `/roller/totalbestand` (~131 MB).
#' @param format Download format: `"csv"` (default for enheter/underenheter,
#'   comma-delimited) or `"json"` (JSON array). Only the JSON bulk
#'   carries `historiskeNavn`; the CSV has no such column. Roller bulk
#'   download is always JSON regardless of this parameter.
#' @param refresh `FALSE` (default): use cached file if available.
#'   `TRUE`: force re-download. `"auto"`: revalidate against the server
#'   and re-download only when the cached copy cannot be shown current.
#'   Any other value is an error.
#' @param cache Logical. If `TRUE` (default), keep the downloaded file in
#'   the persistent cache directory; if `FALSE`, use a temporary file.
#' @param type_output One of `"tibble"` (default) or `"path"` (returns
#'   the file path without parsing).
#'
#' @returns Depends on `type_output`:
#'   - `"tibble"`: A tibble with ~1 million rows. Column names mapped
#'     via [field_dict]. For `type = "roller"`, one row per role
#'     assignment with the columns of [brreg_roles()].
#'   - `"path"`: Character file path to the gzipped download.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_search()] for filtered API queries,
#'   [brreg_updates()] for incremental changes since a given date.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' # Download full register as tibble (~150MB download, ~1M rows)
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
                            type_output = c("tibble", "path")) {
  type <- match.arg(type)
  format <- match.arg(format)
  type_output <- match.arg(type_output)
  if (!(isTRUE(refresh) || isFALSE(refresh) || identical(refresh, "auto"))) {
    brreg_abort("{.arg refresh} must be {.code TRUE}, {.code FALSE}, or {.val auto}.",
                class = "invalid_filter", registry = type, filter = "refresh")
  }
  if (!(isTRUE(cache) || isFALSE(cache))) {
    brreg_abort("{.arg cache} must be {.code TRUE} or {.code FALSE}.",
                class = "invalid_filter", registry = type, filter = "cache")
  }

  if (type == "roller" && format == "csv") {
    format <- "json"
    cli::cli_alert_info("Roller only available as JSON. Using {.val json} format.")
  }

  url <- bulk_url(type, format)
  sizes <- c(enheter = "~152 MB", underenheter = "~59 MB", roller = "~131 MB")

  if (cache) {
    cache_dir <- tools::R_user_dir("tidybrreg", "cache")
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, paste0(type, "_bulk.", format, ".gz"))
    meta_file <- paste0(cache_file, ".meta.json")
    needs_download <- !file.exists(cache_file) || isTRUE(refresh)
    if (identical(refresh, "auto") && file.exists(cache_file)) {
      needs_download <- !cache_is_current(url, meta_file)
    }
  } else {
    cache_file <- tempfile(pattern = paste0(type, "_bulk_"),
                           fileext = paste0(".", format, ".gz"))
    meta_file <- NULL
    needs_download <- TRUE
    if (type_output == "tibble") on.exit(unlink(cache_file), add = TRUE)
  }

  if (needs_download) {
    cli::cli_progress_step("Downloading full {type} register ({sizes[type]})")
    resp <- brreg_http_req(url, path = "", realm = "data.brreg.no",
                           accept = "*/*") |>
      httr2::req_perform(path = cache_file)
    meta <- download_meta(resp, url, cache_file)
    if (!is.null(meta_file)) write_download_meta(meta, meta_file)
    cli::cli_progress_done()
    cli::cli_alert_success("Downloaded {round(file.size(cache_file) / 1024^2, 1)} MB.")
    assign("last_download_resp", resp, envir = .brregEnv)
    assign("last_download_url", url, envir = .brregEnv)
    assign("last_download_meta", meta, envir = .brregEnv)
  } else {
    meta <- read_download_meta(meta_file) %||%
      list(url = url, etag = NA_character_, last_modified = as.POSIXct(NA, tz = "UTC"),
           downloaded_at = as.POSIXct(file.mtime(cache_file), tz = "UTC"),
           path = cache_file)
    mtime <- format(file.mtime(cache_file), "%Y-%m-%d %H:%M")
    cli::cli_alert_info("Using cached file ({round(file.size(cache_file) / 1024^2, 1)} MB, {mtime}).")
  }

  if (identical(type_output, "path")) return(cache_file)

  result <- if (type == "roller") {
    parse_roles_bulk(cache_file)
  } else if (format == "json") {
    parse_bulk_json(cache_file, type = type)
  } else {
    parse_bulk_csv(cache_file, type = type)
  }
  attr(result, "brreg_download") <- meta
  result
}

#' Bulk endpoint URL for a registry and format
#' @keywords internal
bulk_url <- function(type, format) {
  if (type == "roller") return(paste0(brreg_base_url(), "/roller/totalbestand"))
  if (format == "json") return(paste0(brreg_base_url(), "/", type, "/lastned"))
  paste0(brreg_base_url(), "/", type, "/lastned/", format)
}

#' Collect validators and timing of a completed download
#' @keywords internal
download_meta <- function(resp, url, path) {
  list(
    url           = url,
    etag          = httr2::resp_header(resp, "ETag") %||% NA_character_,
    last_modified = parse_http_date(httr2::resp_header(resp, "Last-Modified")),
    downloaded_at = as.POSIXct(Sys.time(), tz = "UTC"),
    path          = path
  )
}

#' @keywords internal
write_download_meta <- function(meta, meta_file) {
  out <- meta
  out$last_modified <- format(meta$last_modified, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  out$downloaded_at <- format(meta$downloaded_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  writeLines(jsonlite::toJSON(out, auto_unbox = TRUE, na = "null"), meta_file)
}

#' @keywords internal
read_download_meta <- function(meta_file) {
  if (is.null(meta_file) || !file.exists(meta_file)) return(NULL)
  meta <- tryCatch(jsonlite::fromJSON(meta_file), error = \(e) NULL)
  if (is.null(meta)) return(NULL)
  meta$etag <- meta$etag %||% NA_character_
  meta$last_modified <- parse_brreg_instant(meta$last_modified %||% NA_character_)
  meta$downloaded_at <- parse_brreg_instant(meta$downloaded_at %||% NA_character_)
  meta
}

#' Decide whether a cached bulk file is provably current
#'
#' Sends a HEAD request and compares `ETag` and `Last-Modified` with the
#' sidecar written at download time. `TRUE` only when at least one
#' validator is present on both sides and every validator present on
#' both sides matches; a missing sidecar, a server that sends no
#' validator, or a failed HEAD all yield `FALSE` (re-download).
#' @keywords internal
cache_is_current <- function(url, meta_file) {
  meta <- read_download_meta(meta_file)
  if (is.null(meta)) return(FALSE)
  resp <- tryCatch(
    brreg_http_req(url, path = "", realm = "data.brreg.no", accept = "*/*") |>
      httr2::req_method("HEAD") |>
      httr2::req_perform(),
    error = \(e) NULL
  )
  if (is.null(resp)) return(FALSE)
  server_etag <- httr2::resp_header(resp, "ETag")
  server_lm <- parse_http_date(httr2::resp_header(resp, "Last-Modified"))
  checks <- logical()
  if (!is.null(server_etag) && !is.na(meta$etag)) {
    checks <- c(checks, identical(server_etag, meta$etag))
  }
  if (!is.na(server_lm) && !is.na(meta$last_modified)) {
    checks <- c(checks, isTRUE(server_lm == meta$last_modified))
  }
  length(checks) > 0 && all(checks)
}


#' Parse a brreg bulk CSV into a tibble using the field dictionary
#'
#' The bulk CSV uses `,` (comma) delimiter with `.` notation for nested fields
#' (e.g. `forretningsadresse.kommune`). This function reads all columns
#' as character, then applies [rename_and_coerce()] for field_dict
#' mapping and type coercion — the same rename/coerce pipeline used
#' by [parse_bulk_json()].
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

  rename_and_coerce(dat)
}


#' Parse a brreg bulk JSON download into a flat tibble
#'
#' The `/enheter/lastned` and `/underenheter/lastned` endpoints return
#' gzipped JSON arrays with nested objects. `jsonlite::fromJSON(flatten = TRUE)`
#' expands nested objects to dot-notation columns but leaves arrays as list
#' columns. This function algorithmically flattens all list columns to
#' atomic types:
#'
#' - Character vectors (addresses, activities): collapsed with separator
#' - Data frames (paategninger): serialized to JSON strings
#' - Empty lists (HAL links): dropped
#' - NULL elements: `NA_character_`
#'
#' Known columns are renamed via [field_dict]. Unknown columns pass through
#' with auto-generated `snake_case` names (zero-drop policy). The raw `.gz`
#' file is the provenance fallback for anyone needing the original nesting.
#'
#' @param path Path to the gzipped JSON file.
#' @param type Entity type (for column context).
#' @returns A tibble with atomic columns only, mapped via [field_dict].
#' @keywords internal
parse_bulk_json <- function(path, type = "enheter") {
  dat <- jsonlite::fromJSON(path, flatten = TRUE)
  dat <- tibble::as_tibble(dat)

  dat <- flatten_list_columns(dat)
  dat <- drop_hal_links(dat)
  dat <- rename_and_coerce(dat)
  dat
}


#' Algorithmically flatten all list columns to atomic types
#'
#' Dispatches on the runtime type of each list column's elements:
#' character/numeric vectors are collapsed, data.frames are serialized
#' to JSON, NULLs become `NA_character_`.
#'
#' @param dat A tibble potentially containing list columns.
#' @returns The same tibble with all list columns converted to character.
#' @keywords internal
flatten_list_columns <- function(dat) {
  list_cols <- names(dat)[vapply(dat, is.list, logical(1))]
  for (col in list_cols) {
    dat[[col]] <- vapply(dat[[col]], flatten_cell, character(1))
  }
  dat
}

#' Flatten a single list-column cell to an atomic character value
#' @keywords internal
flatten_cell <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.data.frame(x)) {
    if (nrow(x) == 0) return(NA_character_)
    return(as.character(jsonlite::toJSON(x, auto_unbox = TRUE)))
  }
  if (is.list(x) && is.null(names(x)) && all(vapply(x, is.null, logical(1)))) {
    return(NA_character_)
  }
  if (is.list(x) && !is.null(names(x))) {
    return(as.character(jsonlite::toJSON(x, auto_unbox = TRUE)))
  }
  collapse_observed(x)
}

#' Drop HAL link columns at any nesting depth (metadata, not data)
#' @keywords internal
drop_hal_links <- function(dat) {
  dat[, !is_hal_link_path(names(dat)), drop = FALSE]
}

#' Rename columns via field_dict and coerce types
#'
#' Shared between CSV and JSON parsing. Known dot-notation paths
#' map to English names; unknown paths get auto snake_case, made unique
#' on collision. Type coercion follows `field_dict$type` through
#' [coerce_column()], the same rule the live path uses, so every
#' dictionary type (including `numeric`) is invariant across sources.
#' Parse failures are attached as a `brreg_parse_problems` attribute.
#'
#' @keywords internal
rename_and_coerce <- function(dat) {
  dat <- drop_hal_links(dat)
  dict <- field_dict
  dict_map <- stats::setNames(dict$col_name, tolower(dict$api_path))
  old_names <- names(dat)

  type_map <- stats::setNames(dict$type, tolower(dict$api_path))
  new_names <- character(length(old_names))
  col_types <- rep(NA_character_, length(old_names))
  taken <- character()
  for (i in seq_along(old_names)) {
    lcn <- tolower(old_names[i])
    cand <- if (lcn %in% names(dict_map) && !dict_map[[lcn]] %in% taken) {
      dict_map[[lcn]]
    } else {
      to_snake(old_names[i])
    }
    if (lcn %in% names(type_map)) col_types[i] <- type_map[[lcn]]
    new_names[i] <- cand
    taken <- c(taken, cand)
  }
  names(dat) <- make.unique(new_names, sep = "_")

  problems <- list()
  for (i in which(!is.na(col_types))) {
    col <- names(dat)[i]
    coerced <- coerce_column(dat[[col]], col_types[i])
    if (length(coerced$failed) > 0) {
      problems[[col]] <- parse_problem_rows(col, col_types[i], dat[[col]], coerced$failed)
    }
    dat[[col]] <- coerced$value
  }
  attach_parse_problems(dat, problems)
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
  raw <- read_roles_json(path)
  flatten_roles_bulk_fast(raw)
}


#' Read roller totalbestand JSON with best available parser
#'
#' Dispatches to yyjsonr (7x faster, 70x less memory) when
#' available, falling back to jsonlite. Both produce nested
#' lists compatible with [flatten_roles_bulk_fast()].
#'
#' @param path Path to the gzipped JSON file.
#' @returns A list of entity objects.
#' @keywords internal
read_roles_json <- function(path) {
  is_gz <- grepl("\\.gz$", path)

  if (requireNamespace("yyjsonr", quietly = TRUE)) {
    opts <- yyjsonr::opts_read_json(
      obj_of_arrs_to_df = FALSE,
      arr_of_objs_to_df = FALSE
    )
    if (is_gz) {
      json_path <- tempfile(fileext = ".json")
      on.exit(unlink(json_path), add = TRUE)
      con_in  <- gzfile(path, open = "rb")
      con_out <- file(json_path, open = "wb")
      while (length(chunk <- readBin(con_in, "raw", n = 2^20)) > 0) {
        writeBin(chunk, con_out)
      }
      close(con_out)
      close(con_in)
      return(yyjsonr::read_json_file(json_path, opts = opts))
    }
    return(yyjsonr::read_json_file(path, opts = opts))
  }

  cli::cli_alert_info(
    "Install {.pkg yyjsonr} for 7x faster JSON parsing and 70x lower memory; jsonlite needs well over 4 GB for the roller bulk."
  )
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}


#' Vectorised bulk flatten of roller totalbestand
#'
#' Two-pass approach: first counts total roles across all entities
#' to pre-allocate vectors, then fills by index. Avoids per-row
#' list construction and the O(n^2) cost of incremental
#' `bind_rows()` on thousands of small tibbles.
#'
#' @param entities List of entity objects from [read_roles_json()].
#' @returns A tibble matching [flatten_roles()] output schema.
#' @keywords internal
flatten_roles_bulk_fast <- function(entities) {

  # --- Pass 1: count total roles ---
  n_total <- 0L
  for (e in entities) {
    for (g in (e$rollegrupper %||% list())) {
      n_total <- n_total + length(g$roller %||% list())
    }
  }

  if (n_total == 0L) return(empty_roles())

  # --- Pre-allocate ---
  v_org_nr          <- character(n_total)
  v_role_group_code <- character(n_total)
  v_role_code       <- character(n_total)
  v_first_name      <- character(n_total)
  v_middle_name     <- character(n_total)
  v_last_name       <- character(n_total)
  v_birth_date      <- character(n_total)
  v_deceased        <- logical(n_total)
  v_entity_org_nr   <- character(n_total)
  v_entity_name     <- character(n_total)
  v_resigned        <- logical(n_total)
  v_deregistered    <- logical(n_total)
  v_ordering        <- integer(n_total)
  v_elected_by      <- character(n_total)
  v_group_modified  <- character(n_total)

  # --- Pass 2: fill by index ---
  k <- 0L
  any_fratraadt <- FALSE
  for (e in entities) {
    org <- e$organisasjonsnummer %||% NA_character_
    for (g in (e$rollegrupper %||% list())) {
      g_code    <- g$type$kode %||% NA_character_
      g_modified <- g$sistEndret %||% NA_character_
      for (r in (g$roller %||% list())) {
        k <- k + 1L
        v_org_nr[k]          <- org
        v_role_group_code[k] <- g_code
        v_role_code[k]       <- r$type$kode %||% NA_character_
        v_first_name[k]      <- r$person$navn$fornavn %||% NA_character_
        v_middle_name[k]     <- r$person$navn$mellomnavn %||% NA_character_
        v_last_name[k]       <- r$person$navn$etternavn %||% NA_character_
        v_birth_date[k]      <- r$person$fodselsdato %||% NA_character_
        v_deceased[k]        <- r$person$erDoed %||% NA
        v_entity_org_nr[k]   <- r$enhet$organisasjonsnummer %||% NA_character_
        v_entity_name[k]     <- extract_entity_name(r$enhet$navn)
        if (!is.null(r$fratraadt)) any_fratraadt <- TRUE
        v_resigned[k]        <- r$fratraadt %||% NA
        v_deregistered[k]    <- r$avregistrert %||% NA
        v_ordering[k]        <- r$rekkefolge %||% NA_integer_
        v_elected_by[k]      <- r$valgtAv$kode %||% NA_character_
        v_group_modified[k]  <- g_modified
      }
    }
  }

  # --- Construct tibble + derived columns ---
  result <- tibble::tibble(
    org_nr          = v_org_nr,
    role_group_code = v_role_group_code,
    role_group      = lookup_role_group_vec(v_role_group_code),
    role_code       = v_role_code,
    role            = lookup_role_vec(v_role_code),
    first_name      = v_first_name,
    middle_name     = v_middle_name,
    last_name       = v_last_name,
    birth_date      = parse_brreg_date(v_birth_date),
    deceased        = v_deceased,
    entity_org_nr   = v_entity_org_nr,
    entity_name     = v_entity_name,
    resigned        = v_resigned,
    deregistered    = v_deregistered,
    ordering        = v_ordering,
    elected_by      = v_elected_by,
    group_modified  = parse_brreg_date(v_group_modified)
  )

  result$person_id <- make_person_id(result)
  if (any_fratraadt) {
    result$resigned[is.na(result$resigned)] <- FALSE
  } else {
    result$resigned <- NULL
  }
  result
}
