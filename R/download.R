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

  sizes <- c(enheter = "~152 MB", underenheter = "~59 MB", roller = "~131 MB")

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
    cli::cli_progress_step("Downloading full {type} register ({sizes[type]})")
    resp <- httr2::request(url) |>
      httr2::req_user_agent("tidybrreg (https://github.com/sondreskarsten/tidybrreg; R package)") |>
      httr2::req_perform(path = cache_file)
    etag <- httr2::resp_header(resp, "ETag")
    if (!is.null(etag) && cache) {
      writeLines(etag, etag_file)
    }
    fsize <- file.size(cache_file)
    cli::cli_progress_done()
    cli::cli_alert_success("Downloaded {round(fsize / 1024^2, 1)} MB to cache.")
    assign("last_download_resp", resp, envir = .brregEnv)
    assign("last_download_url", url, envir = .brregEnv)
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
    return(jsonlite::toJSON(x, auto_unbox = TRUE))
  }
  if (is.list(x) && is.null(names(x)) && all(vapply(x, is.null, logical(1)))) {
    return(NA_character_)
  }
  if (is.list(x) && !is.null(names(x))) {
    return(jsonlite::toJSON(x, auto_unbox = TRUE))
  }
  if (is.atomic(x)) {
    return(paste(as.character(x), collapse = "; "))
  }
  paste(as.character(unlist(x)), collapse = "; ")
}

#' Drop HAL _links columns (metadata, not data)
#' @keywords internal
drop_hal_links <- function(dat) {
  link_cols <- grep("\\.?links$", names(dat), value = TRUE)
  if (length(link_cols) > 0) dat <- dat[, !names(dat) %in% link_cols, drop = FALSE]
  dat
}

#' Rename columns via field_dict and coerce types
#'
#' Shared between CSV and JSON parsing. Known dot-notation paths
#' map to English names; unknown paths get auto snake_case.
#' Type coercion follows `field_dict$type`. Parse failures are
#' tracked and attached as a `brreg_parse_problems` attribute.
#'
#' @keywords internal
rename_and_coerce <- function(dat) {
  dict_map <- stats::setNames(field_dict$col_name, tolower(field_dict$api_path))
  old_names <- names(dat)

  new_names <- vapply(old_names, function(cn) {
    lcn <- tolower(cn)
    if (lcn %in% names(dict_map)) return(dict_map[[lcn]])
    to_snake(cn)
  }, character(1), USE.NAMES = FALSE)

  names(dat) <- new_names

  problems <- list()

  for (i in seq_len(nrow(field_dict))) {
    col <- field_dict$col_name[i]
    target <- field_dict$type[i]
    if (!col %in% names(dat)) {
      dat[[col]] <- switch(target,
        Date      = as.Date(NA_character_),
        integer   = NA_integer_,
        logical   = NA,
        character = NA_character_,
        NA
      )
      next
    }
    if (target == "integer") {
      original <- dat[[col]]
      parsed <- suppressWarnings(as.integer(original))
      failed <- !is.na(original) & original != "" & is.na(parsed)
      if (any(failed)) {
        problems[[col]] <- tibble::tibble(
          column = col, row = which(failed),
          expected = "integer",
          actual = as.character(original[failed])[seq_len(min(sum(failed), 20))]
        )
      }
      dat[[col]] <- parsed
    } else {
      dat[[col]] <- switch(target,
        Date      = as.Date(as.character(dat[[col]])),
        logical   = as.logical(dat[[col]]),
        character = as.character(dat[[col]]),
        dat[[col]]
      )
    }
  }

  if (length(problems) > 0) {
    prob_tbl <- dplyr::bind_rows(problems)
    attr(dat, "brreg_parse_problems") <- prob_tbl
    cli::cli_warn(c(
      "{nrow(prob_tbl)} parse failure{?s} in {length(problems)} column{?s}.",
      "i" = "Use {.code attr(result, \"brreg_parse_problems\")} to inspect."
    ))
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
  if (requireNamespace("yyjsonr", quietly = TRUE)) {
    opts <- yyjsonr::opts_read_json(
      obj_of_arrs_to_df = FALSE,
      arr_of_objs_to_df = FALSE
    )
    return(yyjsonr::read_json_file(path, opts = opts))
  }
  cli::cli_alert_info(
    "Install {.pkg yyjsonr} for 7x faster JSON parsing and 70x lower memory."
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

  if (n_total == 0L) return(tibble::tibble())

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
        v_resigned[k]        <- r$fratraadt %||% FALSE
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
    birth_date      = as.Date(v_birth_date),
    deceased        = v_deceased,
    entity_org_nr   = v_entity_org_nr,
    entity_name     = v_entity_name,
    resigned        = v_resigned,
    deregistered    = v_deregistered,
    ordering        = v_ordering,
    elected_by      = v_elected_by,
    group_modified  = as.Date(v_group_modified)
  )

  result$person_id <- ifelse(
    !is.na(result$birth_date) & !is.na(result$last_name),
    paste(result$birth_date, tolower(result$last_name),
          tolower(result$first_name),
          tolower(ifelse(is.na(result$middle_name), "", result$middle_name)),
          sep = "_"),
    NA_character_
  )
  result
}
