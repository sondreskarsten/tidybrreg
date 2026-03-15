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
#' @param type One of `"enheter"` (main entities) or `"underenheter"`
#'   (sub-entities / establishments).
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
                           type = c("enheter", "underenheter")) {
  type <- match.arg(type)
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


#' Parse brreg flat JSON Patch array into a tibble
#'
#' The brreg API returns field-level changes as a flat interleaved array:
#' `["replace", "/path", "value", "replace", "/path2", "value2", ...]`.
#'
#' @param endringer List or character vector of patch operations.
#'
#' @returns A tibble with columns `operation`, `field`, `new_value`.
#'
#' @keywords internal
parse_patch <- function(endringer) {
  if (is.null(endringer) || length(endringer) == 0) return(tibble::tibble())
  ops <- unlist(endringer)
  i <- 1L
  rows <- list()
  while (i <= length(ops)) {
    op <- ops[i]
    if (op %in% c("replace", "add", "remove")) {
      path <- if (i + 1L <= length(ops)) ops[i + 1L] else NA_character_
      value <- if (op != "remove" && i + 2L <= length(ops)) ops[i + 2L] else NA_character_
      field <- sub("^/", "", path)
      field <- gsub("/", "_", field)
      field <- sub("_\\d+$", "", field)
      rows <- c(rows, list(tibble::tibble(
        operation = op, field = field, new_value = value
      )))
      i <- i + if (op == "remove") 2L else 3L
    } else {
      i <- i + 1L
    }
  }
  dplyr::bind_rows(rows)
}
