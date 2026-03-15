#' Translate codes to human-readable English labels
#'
#' Replace coded values in a brreg tibble with English descriptions.
#' Translations use bundled reference data by default. For NACE industry
#' codes and institutional sector codes, fresh labels can be fetched from
#' the SSB Klass API via `refresh = TRUE`.
#'
#' This implements the label-on-demand pattern: functions like
#' [brreg_entity()] and [brreg_search()] return codes by default, and
#' `brreg_label()` translates them post-hoc. Original codes are preserved
#' in `attr(result, "original_codes")`.
#'
#' @param data A tibble returned by [brreg_entity()], [brreg_search()],
#'   or [brreg_roles()].
#' @param cols Character vector of columns to label. Default `NULL`
#'   labels all recognized code columns: `legal_form`, `nace_1`, `nace_2`,
#'   `nace_3`, `sector_code`, `role_group_code`, `role_code`.
#' @param refresh Logical. If `TRUE`, fetch current NACE and sector
#'   labels from the SSB Klass API instead of using bundled data.
#'   Requires internet access. Defaults to `FALSE`.
#'
#' @returns The input tibble with code columns replaced by English labels.
#'   Original codes are stored in `attr(result, "original_codes")` as a
#'   named list.
#'
#' @family tidybrreg utilities
#' @seealso [legal_forms], [role_types], [role_groups] for bundled
#'   reference data.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' eq <- brreg_entity("923609016")
#' eq$legal_form          # "ASA"
#' brreg_label(eq)$legal_form  # "Public limited company"
#'
#' # Label only specific columns
#' brreg_label(eq, cols = "nace_1")
#'
#' # Refresh NACE labels from SSB Klass API
#' brreg_label(eq, refresh = TRUE)
brreg_label <- function(data, cols = NULL, refresh = FALSE) {
  if (nrow(data) == 0) return(data)

  nace_lkp <- nace_codes
  sector_lkp <- sector_codes
  if (refresh) {
    nace_lkp <- tryCatch(fetch_klass(6), error = \(e) {
      cli::cli_warn("Could not refresh NACE codes from SSB Klass; using bundled data.")
      nace_codes
    })
    sector_lkp <- tryCatch(fetch_klass(39), error = \(e) {
      cli::cli_warn("Could not refresh sector codes from SSB Klass; using bundled data.")
      sector_codes
    })
  }

  label_map <- list(
    legal_form      = stats::setNames(legal_forms$name_en, legal_forms$code),
    nace_1          = stats::setNames(nace_lkp$name_en, nace_lkp$code),
    nace_2          = stats::setNames(nace_lkp$name_en, nace_lkp$code),
    nace_3          = stats::setNames(nace_lkp$name_en, nace_lkp$code),
    sector_code     = stats::setNames(sector_lkp$name_en, sector_lkp$code),
    role_group_code = stats::setNames(role_groups$name_en, role_groups$code),
    role_code       = stats::setNames(role_types$name_en, role_types$code)
  )

  if (is.null(cols)) {
    cols <- intersect(names(label_map), names(data))
  } else {
    cols <- intersect(cols, names(data))
  }
  if (length(cols) == 0) return(data)

  originals <- list()
  for (col in cols) {
    if (!col %in% names(label_map)) next
    lkp <- label_map[[col]]
    originals[[col]] <- data[[col]]
    matched <- lkp[data[[col]]]
    data[[col]] <- ifelse(is.na(matched), data[[col]], unname(matched))
  }
  attr(data, "original_codes") <- originals
  data
}


#' Fetch English classification labels from SSB Klass API
#'
#' @param classification_id Integer. SSB Klass classification ID
#'   (6 = SN2007/NACE, 39 = institutional sector).
#' @param date Date for which codes are valid.
#'
#' @returns A tibble with columns `code`, `name_en`, `level`.
#'
#' @keywords internal
fetch_klass <- function(classification_id, date = Sys.Date()) {
  resp <- httr2::request("https://data.ssb.no/api/klass/v1") |>
    httr2::req_url_path_append("classifications", classification_id, "codesAt") |>
    httr2::req_url_query(date = format(date, "%Y-%m-%d"), language = "en") |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_user_agent("brreg (R package)") |>
    httr2::req_perform()
  body <- httr2::resp_body_json(resp)
  dplyr::bind_rows(lapply(body$codes, \(c) tibble::tibble(
    code = c$code, name_en = c$name, level = c$level
  )))
}
