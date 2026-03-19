#' Translate codes to human-readable English labels
#'
#' Replace coded values in a brreg tibble with English descriptions,
#' following the eurostat package's `label_eurostat()` pattern. Works on
#' both data frames and character vectors.
#'
#' @param x A tibble from [brreg_entity()], [brreg_search()], or
#'   [brreg_roles()], or a character vector of codes.
#' @param dic A character string naming the dictionary to use when `x`
#'   is a character vector. One of `"legal_form"`, `"nace"`,
#'   `"sector"`, `"role"`, `"role_group"`. Ignored when `x` is a
#'   data frame (dictionaries are inferred from column names).
#' @param code For data frames: character vector of column names for
#'   which to retain the original code alongside the label. A column
#'   with suffix `_code` is added. For example,
#'   `brreg_label(x, code = "legal_form")` adds `legal_form_code`.
#' @param lang Language for NACE and sector labels. `"en"` (default)
#'   or `"no"` (Norwegian original from brreg API).
#'
#' @returns When `x` is a data frame: the same tibble with code columns
#'   replaced by English labels. When `x` is a character vector: a
#'   character vector of labels.
#'
#' @family tidybrreg utilities
#' @seealso [legal_forms], [role_types], [role_groups] for bundled
#'   reference data, [get_brreg_dic()] for fetching fresh dictionaries.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' eq <- brreg_entity("923609016")
#'
#' # Label all code columns
#' brreg_label(eq)
#'
#' # Keep original codes alongside labels
#' brreg_label(eq, code = "legal_form")
#'
#' # Label a character vector directly
#' brreg_label(c("AS", "ASA", "ENK"), dic = "legal_form")
brreg_label <- function(x, dic = NULL, code = NULL, lang = "en") {
  if (is.data.frame(x)) {
    label_df(x, code = code, lang = lang)
  } else {
    if (is.null(dic)) {
      cli::cli_abort("When {.arg x} is a vector, {.arg dic} must be provided.")
    }
    label_vec(x, dic = dic, lang = lang)
  }
}

#' Label a data frame — iterates over columns
#' @keywords internal
label_df <- function(x, code = NULL, lang = "en") {
  if (nrow(x) == 0) return(x)

  lkp <- build_label_map(lang)
  labelable <- intersect(names(lkp), names(x))
  skip <- c("org_nr", "name", "employees", "founding_date", "registration_date",
            "website", "business_address", "business_postcode", "business_city",
            "municipality_code", "municipality", "country_code", "country",
            "postal_address", "postal_postcode", "postal_city",
            "postal_municipality_code", "postal_municipality",
            "postal_country_code", "postal_country",
            "location_address", "location_postcode", "location_city",
            "location_municipality_code", "location_municipality",
            "location_country_code", "location_country",
            "foreign_reg_address", "foreign_reg_country", "foreign_reg_city",
            "bankrupt", "bankruptcy_date", "in_liquidation", "liquidation_date",
            "forced_dissolution", "vat_registered", "in_business_register",
            "in_nonprofit_register", "parent_org_nr", "in_corporate_group",
            "purpose", "timestamp", "update_id", "change_type",
            "deletion_date", "ownership_change_date",
            "first_name", "middle_name", "last_name", "birth_date",
            "deceased", "entity_org_nr", "entity_name", "resigned", "person_id")
  labelable <- setdiff(labelable, skip)

  if (!is.null(code)) {
    code <- intersect(code, labelable)
    for (col in code) {
      code_col <- paste0(col, "_code")
      x[[code_col]] <- x[[col]]
      col_pos <- which(names(x) == col)
      nc <- ncol(x)
      x <- x[, c(seq_len(col_pos - 1), nc, col_pos:(nc - 1)), drop = FALSE]
    }
  }

  for (col in labelable) {
    if (!col %in% names(lkp)) next
    matched <- lkp[[col]][enc2utf8(x[[col]])]
    x[[col]] <- ifelse(is.na(matched), x[[col]], unname(matched))
  }
  x
}

#' Label a character vector using a named dictionary
#' @keywords internal
label_vec <- function(x, dic, lang = "en") {
  lkp <- build_label_map(lang)
  dic_map <- switch(dic,
    legal_form = lkp[["legal_form"]],
    nace       = lkp[["nace_1"]],
    sector     = lkp[["sector_code"]],
    role       = lkp[["role_code"]],
    role_group = lkp[["role_group_code"]],
    cli::cli_abort("Unknown dictionary: {.val {dic}}. Options: legal_form, nace, sector, role, role_group.")
  )
  matched <- dic_map[enc2utf8(x)]
  ifelse(is.na(matched), x, unname(matched))
}

#' Build the complete label lookup map
#' @keywords internal
build_label_map <- function(lang = "en") {
  nace_lkp <- get_brreg_dic("nace", lang = lang)
  sector_lkp <- get_brreg_dic("sector", lang = lang)

  list(
    legal_form      = stats::setNames(legal_forms$name_en, enc2utf8(legal_forms$code)),
    nace_1          = stats::setNames(nace_lkp$name_en, enc2utf8(nace_lkp$code)),
    nace_2          = stats::setNames(nace_lkp$name_en, enc2utf8(nace_lkp$code)),
    nace_3          = stats::setNames(nace_lkp$name_en, enc2utf8(nace_lkp$code)),
    nace_1_desc     = stats::setNames(nace_lkp$name_en, enc2utf8(nace_lkp$code)),
    sector_code     = stats::setNames(sector_lkp$name_en, enc2utf8(sector_lkp$code)),
    role_group_code = stats::setNames(role_groups$name_en, enc2utf8(role_groups$code)),
    role_code       = stats::setNames(role_types$name_en, enc2utf8(role_types$code))
  )
}


#' Fetch a brreg dictionary
#'
#' Retrieve English or Norwegian label dictionaries for NACE industry
#' codes or institutional sector codes. Dictionaries are cached in a
#' session-level environment (following the eurostat package pattern).
#' Bundled data is used as fallback when the SSB Klass API is
#' unreachable.
#'
#' @param dictname One of `"nace"` or `"sector"`.
#' @param lang `"en"` (default) for English labels or `"no"` for
#'   Norwegian.
#'
#' @returns A tibble with columns `code`, `name_en`, `level`.
#'
#' @family tidybrreg utilities
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' get_brreg_dic("nace")
#' get_brreg_dic("sector")
get_brreg_dic <- function(dictname = c("nace", "sector"), lang = "en") {
  dictname <- match.arg(dictname)
  cache_key <- paste0(dictname, "_", lang)

  if (exists(cache_key, envir = .brregEnv)) {
    return(get(cache_key, envir = .brregEnv))
  }

  classification_id <- switch(dictname, nace = 6L, sector = 39L)
  result <- tryCatch(
    fetch_klass(classification_id, lang = lang),
    error = \(e) {
      fallback <- switch(dictname, nace = nace_codes, sector = sector_codes)
      fallback
    }
  )

  assign(cache_key, result, envir = .brregEnv)
  result
}


#' Fetch English classification labels from SSB Klass API
#' @param classification_id Integer. SSB Klass classification ID
#'   (6 = SN2007/NACE, 39 = institutional sector).
#' @param lang Language code: `"en"` or `"no"`.
#' @param date Date for which codes are valid.
#' @returns A tibble with columns `code`, `name_en`, `level`.
#' @keywords internal
fetch_klass <- function(classification_id, lang = "en", date = Sys.Date()) {
  resp <- httr2::request("https://data.ssb.no/api/klass/v1") |>
    httr2::req_url_path_append("classifications", classification_id, "codesAt") |>
    httr2::req_url_query(date = format(date, "%Y-%m-%d"), language = lang) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_user_agent("tidybrreg (R package)") |>
    httr2::req_perform()
  body <- httr2::resp_body_json(resp)
  dplyr::bind_rows(lapply(body$codes, \(c) tibble::tibble(
    code = c$code, name_en = c$name, level = c$level
  )))
}
