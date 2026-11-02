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
#' - **`brreg_download()`**: Bulk JSON. Always returns the full
#'   register. Appropriate for any analysis requiring more than 10,000
#'   entities.
#'
#' Results from both paths use the same column names and types via
#' [field_dict]; only observed columns are emitted (see
#' [brreg_entity()]). The bulk is the JSON variant of each endpoint,
#' the same representation the single-entity lookups and the update
#' feeds use, so `historiskeNavn` and `paategninger` arrive as the
#' nested list-columns `historiske_navn` and `annotations` exactly as
#' from [brreg_entity()]. BRREG's CSV variant is not read: it is the
#' register's own flattening, with different separators and a presence
#' flag in place of the annotation array.
#'
#' @inheritSection brreg_entity Tidy shape
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
#' @param type One of `"enheter"` (main entities, default, ~196 MB),
#'   `"underenheter"` (sub-entities / establishments, ~75 MB), or
#'   `"roller"` (all roles for all entities via `/roller/totalbestand`,
#'   ~131 MB). All three are gzipped JSON.
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
#'     via [field_dict]; arrays of objects are list-columns of tibbles.
#'     For `type = "roller"`, one row per role assignment with the
#'     columns of [brreg_roles()].
#'   - `"path"`: Character file path to the gzipped download.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_search()] for filtered API queries,
#'   [brreg_updates()] for incremental changes since a given date.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' # Download full register as tibble (~196 MB download, ~1M rows)
#' entities <- brreg_download()
#'
#' # Just get the file path (no parsing)
#' path <- brreg_download(type_output = "path")
#'
#' # Force refresh
#' entities <- brreg_download(refresh = TRUE)
#' }
brreg_download <- function(type = c("enheter", "underenheter", "roller"),
                            refresh = FALSE,
                            cache = TRUE,
                            type_output = c("tibble", "path")) {
  type <- match.arg(type)
  type_output <- match.arg(type_output)
  if (!(isTRUE(refresh) || isFALSE(refresh) || identical(refresh, "auto"))) {
    brreg_abort("{.arg refresh} must be {.code TRUE}, {.code FALSE}, or {.val auto}.",
                class = "invalid_filter", registry = type, filter = "refresh")
  }
  if (!(isTRUE(cache) || isFALSE(cache))) {
    brreg_abort("{.arg cache} must be {.code TRUE} or {.code FALSE}.",
                class = "invalid_filter", registry = type, filter = "cache")
  }

  url <- bulk_url(type)
  sizes <- c(enheter = "~196 MB", underenheter = "~75 MB", roller = "~131 MB")

  if (cache) {
    cache_dir <- tools::R_user_dir("tidybrreg", "cache")
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, paste0(type, "_bulk.json.gz"))
    meta_file <- paste0(cache_file, ".meta.json")
    needs_download <- !file.exists(cache_file) || isTRUE(refresh)
    if (identical(refresh, "auto") && file.exists(cache_file)) {
      needs_download <- !cache_is_current(url, meta_file)
    }
  } else {
    cache_file <- tempfile(pattern = paste0(type, "_bulk_"), fileext = ".json.gz")
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
  } else {
    parse_bulk_json(cache_file, type = type)
  }
  attr(result, "brreg_download") <- meta
  result
}

#' Bulk endpoint URL for a registry
#' @keywords internal
bulk_url <- function(type) {
  if (type == "roller") return(paste0(brreg_base_url(), "/roller/totalbestand"))
  paste0(brreg_base_url(), "/", type, "/lastned")
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


#' Parse a brreg bulk JSON download into a flat tibble
#'
#' The `/enheter/lastned` and `/underenheter/lastned` endpoints return
#' gzipped JSON arrays with nested objects. `jsonlite::fromJSON(flatten = TRUE)`
#' expands nested objects to dot-notation columns but leaves arrays as list
#' columns. The array is read in batches of complete objects
#' ([read_json_objects()]) and each batch parsed on its own, so the
#' whole decoded tree is never in memory at once; with a finite `n_max`
#' only the first `n_max` elements are read, which is how a sample of
#' the register is parsed. Every list column gets the tidy shape of the
#' live path ([collapse_observed()]):
#'
#' - Character vectors (addresses, activities): line fragments of one
#'   value, joined with `"\n"`
#' - Data frames (`paategninger`, `historiskeNavn`): kept as a
#'   list-column of tibbles, one row per element, `NULL` where the
#'   entity has none
#' - Empty lists (HAL links): dropped
#' - NULL elements: `NA_character_`
#'
#' Known columns are renamed via [field_dict]. Unknown columns pass through
#' with auto-generated `snake_case` names (zero-drop policy). The raw `.gz`
#' file is the provenance fallback for anyone needing the original nesting.
#'
#' @param path Path to the gzipped JSON file.
#' @param type Entity type (for column context).
#' @param n_max Maximum number of array elements to read (default: all).
#' @returns A tibble mapped via [field_dict]; arrays of objects are
#'   nested list-columns, everything else atomic.
#' @keywords internal
parse_bulk_json <- function(path, type = "enheter", n_max = Inf) {
  batches <- list()
  read_json_objects(path, n_max = n_max, emit = function(text) {
    dat <- jsonlite::fromJSON(text, flatten = TRUE)
    if (length(dat) == 0) return(invisible())
    dat <- drop_hal_links(flatten_list_columns(tibble::as_tibble(dat)))
    batches[[length(batches) + 1L]] <<- dat
  })
  if (length(batches) == 0) return(empty_entities())
  rename_and_coerce(dplyr::bind_rows(batches))
}


#' Stream the objects of a gzipped JSON array in batches
#'
#' The bulk is a JSON array of more than a million objects; parsing it
#' in one call holds the whole decoded tree in memory, which is what
#' exhausted the stress-test runners. This reader walks the file in
#' fixed-size byte chunks and emits the array in batches of
#' `batch_size` complete top-level objects, each as its own JSON array
#' text, so the caller parses one batch at a time. Object boundaries
#' are found with a vectorised scan: unescaped quotes delimit string
#' literals, braces outside them change the depth, and an object ends
#' where the depth returns to zero. Nothing beyond `n_max` objects is
#' read, so a sample of a 200 MB bulk costs a few megabytes.
#'
#' @param path Path to a gzipped (or plain) JSON array file.
#' @param emit Function called with the JSON text of each batch.
#' @param n_max Maximum number of objects to read (default: all).
#' @param batch_size Objects per batch.
#' @param chunk_size Bytes read from the file per step.
#' @returns The number of objects emitted, invisibly.
#' @keywords internal
read_json_objects <- function(path, emit, n_max = Inf, batch_size = 25000L,
                              chunk_size = 16777216L) {
  con <- gzfile(path, open = "rb")
  on.exit(close(con))
  buf <- raw()
  state <- list(depth = 0L, in_string = FALSE, scanned = 0L, bs_run = 0L)
  pending <- integer()
  emitted <- 0L
  started <- FALSE
  flush <- function(k) {
    end <- pending[k]
    probe <- buf[seq_len(min(end, 256L))]
    lead <- which(!(probe %in% as.raw(c(0x20, 0x09, 0x0a, 0x0d, 0x2c))))[1]
    text <- rawToChar(buf[seq.int(lead, end)])
    Encoding(text) <- "UTF-8"
    emit(paste0("[", text, "]"))
    buf <<- buf[-seq_len(end)]
    pending <<- pending[-seq_len(k)] - end
    state$scanned <<- state$scanned - end
    emitted <<- emitted + k
  }
  repeat {
    chunk <- readBin(con, what = "raw", n = chunk_size)
    eof <- length(chunk) == 0L
    if (!eof) {
      if (!started) {
        lead <- which(chunk == as.raw(0x5b))[1]
        if (is.na(lead)) {
          if (all(chunk %in% as.raw(c(0x20, 0x09, 0x0a, 0x0d)))) next
          stop("not a JSON array", call. = FALSE)
        }
        chunk <- chunk[-seq_len(lead)]
        started <- TRUE
      }
      buf <- c(buf, chunk)
      scan <- scan_json_objects(buf, state)
      state <- scan$state
      pending <- c(pending, scan$ends)
    }
    while (length(pending) >= batch_size || (eof && length(pending) > 0L)) {
      k <- min(length(pending), batch_size, n_max - emitted)
      if (k <= 0L) break
      flush(k)
    }
    if (eof || emitted >= n_max) break
  }
  invisible(emitted)
}

#' Find the top-level object ends in the unscanned part of a buffer
#'
#' Vectorised: the positions of quotes not preceded by an odd run of
#' backslashes toggle the string state; braces outside strings move the
#' depth; a `}` that brings the depth back to zero ends an object. The
#' state (depth, string flag, bytes already scanned) carries across
#' calls so each byte is examined once.
#' @keywords internal
scan_json_objects <- function(buf, state) {
  n <- length(buf)
  if (state$scanned >= n) return(list(ends = integer(), state = state))
  idx <- seq.int(state$scanned + 1L, n)
  seg <- buf[idx]
  is_bs <- seg == as.raw(0x5c)
  pos <- seq_along(seg)
  run <- pos - cummax(pos * !is_bs)
  if (state$bs_run > 0L) run <- run + (run == pos) * state$bs_run
  bs_run <- if (is_bs[length(seg)]) run[length(seg)] else 0L
  quotes <- which(seg == as.raw(0x22))
  if (length(quotes) > 0L) {
    before <- quotes - 1L
    escaped <- ifelse(before >= 1L, run[pmax(before, 1L)] %% 2L == 1L, state$bs_run %% 2L == 1L)
    quotes <- quotes[!escaped]
  }
  in_string <- state$in_string
  opens <- which(seg == as.raw(0x7b))
  closes <- which(seg == as.raw(0x7d))
  if (length(quotes) == 0L && in_string) {
    opens <- integer()
    closes <- integer()
  }
  if (length(quotes) > 0L) {
    bounds <- c(if (in_string) 0L, quotes)
    if (length(bounds) %% 2L == 1L) bounds <- c(bounds, n + 1L)
    starts <- bounds[seq(1L, length(bounds), by = 2L)]
    stops <- bounds[seq(2L, length(bounds), by = 2L)]
    inside <- function(p) {
      i <- findInterval(p, starts)
      i > 0L & p < stops[pmax(i, 1L)]
    }
    opens <- opens[!inside(opens)]
    closes <- closes[!inside(closes)]
    in_string <- (length(quotes) + as.integer(state$in_string)) %% 2L == 1L
  }
  events <- c(opens, closes)
  ends <- integer()
  depth <- state$depth
  if (length(events) > 0L) {
    ord <- order(events)
    delta <- c(rep(1L, length(opens)), rep(-1L, length(closes)))[ord]
    events <- events[ord]
    depths <- depth + cumsum(delta)
    ends <- events[delta == -1L & depths == 0L] + state$scanned
    depth <- depths[length(depths)]
  }
  list(ends = ends, state = list(depth = depth, in_string = in_string, scanned = n, bs_run = bs_run))
}

#' Read the first elements of a gzipped JSON array as JSON text
#' @param path Path to a gzipped (or plain) JSON array file.
#' @param n Number of elements to read.
#' @returns A length-1 character JSON array.
#' @keywords internal
read_json_head <- function(path, n) {
  parts <- character()
  read_json_objects(path, function(text) parts <<- c(parts, text), n_max = n, batch_size = n)
  if (length(parts) == 0L) return("[]")
  paste0("[", paste(vapply(parts, function(t) substr(t, 2L, nchar(t) - 1L), character(1)), collapse = ","), "]")
}

#' Give every list column its tidy shape
#'
#' Dispatches on the runtime type of each list column's elements:
#' character/numeric vectors are collapsed, NULLs become
#' `NA_character_`, and a column whose elements are data frames stays a
#' list-column of tibbles (`NULL` where the entity has none). A list
#' column with no observed value at all (every array empty) is dropped,
#' as an empty array emits no key on the live path, so batches with and
#' without the array bind.
#'
#' @param dat A tibble potentially containing list columns.
#' @returns The same tibble with list columns converted to character or
#'   to list-columns of tibbles.
#' @keywords internal
flatten_list_columns <- function(dat) {
  list_cols <- names(dat)[vapply(dat, is.list, logical(1))]
  for (col in list_cols) {
    cells <- lapply(dat[[col]], flatten_cell)
    nested <- vapply(cells, is.data.frame, logical(1))
    if (any(nested)) {
      dat[[col]] <- lapply(cells, function(v) if (is.data.frame(v)) v else NULL)
    } else {
      values <- vapply(cells, function(v) v, character(1))
      if (all(is.na(values))) dat[[col]] <- NULL else dat[[col]] <- values
    }
  }
  dat
}

#' Flatten a single list-column cell to its tidy value
#'
#' A character scalar, or a tibble for an array of objects; a single
#' named object (not an array) is serialized to JSON text.
#' @keywords internal
flatten_cell <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.data.frame(x)) {
    if (nrow(x) == 0) return(NA_character_)
    return(nest_records(x))
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
#' Used by [parse_bulk_json()]. Known dot-notation paths
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
