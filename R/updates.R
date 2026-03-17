#' Retrieve incremental entity updates
#'
#' Query the brreg change data capture (CDC) endpoint for entities
#' modified since a given date. Each update carries a monotonically
#' increasing `update_id` suitable for cursor-based pagination and
#' deduplication.
#'
#' @param since Date or POSIXct. Return updates after this timestamp.
#'   Defaults to yesterday.
#' @param size Integer. Number of updates to fetch (max 10000).
#' @param include_changes Logical. If `TRUE`, include field-level change
#'   details per update as a list-column of tibbles. The brreg API
#'   returns changes in a flat RFC 6902-style JSON Patch format.
#' @param type One of `"enheter"` (main entities), `"underenheter"`
#'   (sub-entities), or `"roller"` (role assignments). Roller updates
#'   use CloudEvents format (`afterTime`/`afterId` pagination) rather
#'   than the HAL-based format used by enheter/underenheter.
#'   `include_changes` is ignored for roller.
#'
#' @returns A tibble with columns: `update_id` (integer), `org_nr`
#'   (character), `change_type` (character: Ny/Endring/Sletting),
#'   `timestamp` (POSIXct). If `include_changes = TRUE`, an additional
#'   list-column `changes` contains tibbles with columns `operation`,
#'   `field`, `new_value`.
#'
#' @family tidybrreg entity functions
#' @seealso [brreg_entity()] to fetch the current state of a changed entity.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' brreg_updates(since = Sys.Date() - 1, size = 10)
#'
#' # With field-level change details
#' brreg_updates(since = Sys.Date() - 1, size = 5, include_changes = TRUE)
brreg_updates <- function(since = Sys.Date() - 1, size = 100,
                           include_changes = FALSE,
                           type = c("enheter", "underenheter", "roller")) {
  type <- match.arg(type)

  if (type == "roller") return(brreg_updates_roller(since, size))

  dato <- format(as.POSIXct(since), "%Y-%m-%dT00:00:00.000Z")
  query <- list(dato = dato, size = min(size, 10000L))
  if (include_changes) query$includeChanges <- "true"

  resp <- brreg_req(paste0("oppdateringer/", type)) |>
    httr2::req_url_query(!!!query) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) return(tibble::tibble())

  body <- httr2::resp_body_json(resp)
  key <- paste0("oppdaterte", tools::toTitleCase(type))
  updates <- body[["_embedded"]][[key]]
  if (is.null(updates) || length(updates) == 0) return(tibble::tibble())

  dplyr::bind_rows(lapply(updates, \(u) {
    base <- tibble::tibble(
      update_id   = u$oppdateringsid,
      org_nr      = u$organisasjonsnummer,
      change_type = u$endringstype,
      timestamp   = as.POSIXct(u$dato, format = "%Y-%m-%dT%H:%M:%OS")
    )
    if (include_changes && !is.null(u$endringer)) {
      base$changes <- list(parse_patch(u$endringer))
    }
    base
  }))
}


#' Fetch roller updates (CloudEvents format)
#' @keywords internal
brreg_updates_roller <- function(since, size) {
  after_time <- format(as.POSIXct(since), "%Y-%m-%dT00:00:00.000Z")
  query <- list(afterTime = after_time, size = min(size, 10000L))

  resp <- brreg_req("oppdateringer/roller") |>
    httr2::req_url_query(!!!query) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) return(tibble::tibble())

  events <- httr2::resp_body_json(resp)
  if (length(events) == 0) return(tibble::tibble())

  dplyr::bind_rows(lapply(events, \(e) {
    tibble::tibble(
      update_id   = as.integer(e$id %||% NA),
      org_nr      = e$data$organisasjonsnummer %||% NA_character_,
      change_type = sub(".*\\.", "", e$type %||% ""),
      timestamp   = as.POSIXct(e$time, format = "%Y-%m-%dT%H:%M:%OS")
    )
  }))
}


#' Parse brreg RFC 6902 JSON Patch operations into a tibble
#'
#' The brreg CDC endpoint returns `endringer` as a list of patch
#' objects, each with `op`, `path`, and optionally `value`. Values
#' may be scalars or nested objects (e.g. the full
#' `naeringskode1` or `forretningsadresse` object). Nested objects
#' are flattened to leaf-level rows so that `/naeringskode1` with
#' value `{kode: "43.210", beskrivelse: "..."}` produces two rows:
#' `naeringskode1_kode` and `naeringskode1_beskrivelse`.
#'
#' @param endringer List of patch operations from the brreg API.
#'
#' @returns A tibble with columns `operation`, `field`, `new_value`.
#'   All `new_value` entries are character. Array-index suffixes
#'   (e.g. `adresse_0`) are preserved.
#'
#' @keywords internal
parse_patch <- function(endringer) {
  if (is.null(endringer) || length(endringer) == 0) return(tibble::tibble())
  dplyr::bind_rows(lapply(endringer, function(e) {
    op <- e$op %||% NA_character_
    path <- sub("^/", "", e$path %||% "")
    if (op == "remove" || is.null(e$value)) {
      field <- gsub("/", "_", path)
      return(tibble::tibble(operation = op, field = field, new_value = NA_character_))
    }
    flatten_value(op, path, e$value)
  }))
}


#' Recursively flatten a patch value to leaf-level rows
#' @keywords internal
flatten_value <- function(op, path_prefix, value) {
  if (is.list(value) && !is.null(names(value))) {
    dplyr::bind_rows(lapply(names(value), function(key) {
      child_path <- paste0(path_prefix, "/", key)
      flatten_value(op, child_path, value[[key]])
    }))
  } else if (is.list(value) && is.null(names(value))) {
    dplyr::bind_rows(lapply(seq_along(value), function(i) {
      child_path <- paste0(path_prefix, "/", i - 1L)
      flatten_value(op, child_path, value[[i]])
    }))
  } else {
    field <- gsub("/", "_", path_prefix)
    tibble::tibble(
      operation = op,
      field = field,
      new_value = as.character(value)
    )
  }
}
