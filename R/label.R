#' Translate codes to human-readable labels
#'
#' Replace coded values in a brreg tibble with English (or Norwegian)
#' descriptions, following the eurostat package's `label_eurostat()`
#' pattern. Works on both data frames and character vectors.
#'
#' @section Which columns are labelled:
#' `legal_form` (from [legal_forms]), `role_code` (from [role_types]),
#' `role_group_code` (from [role_groups]), `nace_1`, `nace_2`, `nace_3`
#' and `sector_code` (from the NACE and institutional-sector
#' dictionaries of [get_brreg_dic()]). Other columns are never touched.
#' Codes with no dictionary entry pass through unchanged, and labels
#' are not codes, so applying `brreg_label()` twice is the same as
#' applying it once. Attributes of the input (such as
#' `total_matches` from [brreg_search()]) are preserved.
#'
#' @section Network access:
#' Legal-form and role dictionaries are bundled and never need the
#' network. NACE and sector dictionaries come from the SSB KLASS API on
#' first use in a session and are cached for the session; when KLASS
#' cannot be reached, or `options(tidybrreg.offline = TRUE)` is set, the
#' bundled English dictionaries are used instead and the result carries
#' their vintage. See [get_brreg_dic()] for the full policy.
#'
#' @param x A tibble from [brreg_entity()], [brreg_search()], or
#'   [brreg_roles()], or a character vector of codes.
#' @param dic A character string naming the dictionary to use when `x`
#'   is a character vector. One of `"legal_form"`, `"nace"`,
#'   `"sector"`, `"role"`, `"role_group"`. Ignored when `x` is a
#'   data frame (dictionaries are inferred from column names).
#' @param code For data frames: character vector of column names for
#'   which to retain the original code alongside the label. A column
#'   with suffix `_code` is added before the label column. For example,
#'   `brreg_label(x, code = "legal_form")` adds `legal_form_code`.
#' @param lang Language for labels: `"en"` (default) or `"no"`
#'   (Norwegian, as published by BRREG and SSB).
#'
#' @returns When `x` is a data frame: the same tibble with code columns
#'   replaced by labels. When `x` is a character vector: a character
#'   vector of labels, without names.
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
#' brreg_label(c("AS", "ASA", "ENK"), dic = "legal_form", lang = "no")
brreg_label <- function(x, dic = NULL, code = NULL, lang = c("en", "no")) {
  lang <- match.arg(lang)
  if (is.data.frame(x)) {
    label_df(x, code = code, lang = lang)
  } else {
    if (is.null(dic)) {
      cli::cli_abort("When {.arg x} is a vector, {.arg dic} must be provided.")
    }
    label_vec(x, dic = dic, lang = lang)
  }
}

#' Columns that are labelled, and the dictionary each one uses
#' @keywords internal
labelable_columns <- function() {
  c(legal_form = "legal_form", nace_1 = "nace", nace_2 = "nace",
    nace_3 = "nace", sector_code = "sector", role_code = "role",
    role_group_code = "role_group")
}

#' Label a data frame — iterates over columns
#' @keywords internal
label_df <- function(x, code = NULL, lang = "en") {
  if (nrow(x) == 0) return(x)
  cols <- labelable_columns()
  present <- intersect(names(cols), names(x))
  if (length(present) == 0) return(x)
  keep_attrs <- attributes(x)
  keep_attrs <- keep_attrs[!names(keep_attrs) %in% c("names", "row.names", "class")]

  if (!is.null(code)) {
    for (col in intersect(code, present)) {
      code_col <- paste0(col, "_code")
      x[[code_col]] <- x[[col]]
      col_pos <- which(names(x) == col)
      nc <- ncol(x)
      x <- x[, c(seq_len(col_pos - 1), nc, col_pos:(nc - 1)), drop = FALSE]
    }
  }

  dics <- unique(cols[present])
  maps <- stats::setNames(lapply(dics, label_map, lang = lang), dics)
  for (col in present) {
    x[[col]] <- apply_label_map(x[[col]], maps[[cols[[col]]]])
  }
  for (nm in names(keep_attrs)) attr(x, nm) <- keep_attrs[[nm]]
  x
}

#' Label a character vector using a named dictionary
#' @keywords internal
label_vec <- function(x, dic, lang = "en") {
  dic <- as.character(dic)
  if (!dic %in% c("legal_form", "nace", "sector", "role", "role_group")) {
    cli::cli_abort("Unknown dictionary: {.val {dic}}. Options: legal_form, nace, sector, role, role_group.")
  }
  apply_label_map(x, label_map(dic, lang = lang))
}

#' Replace matched codes by labels, leaving everything else as is
#'
#' Returns a plain character vector with no names attribute, so a
#' labelled column carries nothing beyond its values.
#' @keywords internal
apply_label_map <- function(x, map) {
  x <- as.character(x)
  idx <- match(enc2utf8(x), names(map))
  hit <- !is.na(idx)
  out <- x
  out[hit] <- unname(map[idx[hit]])
  unname(out)
}

#' Named code-to-label vector for one dictionary and language
#' @keywords internal
label_map <- function(dic, lang = "en") {
  name_col <- if (lang == "no") "name_no" else "name_en"
  tbl <- switch(dic,
    legal_form = legal_forms,
    role       = role_types,
    role_group = role_groups,
    nace       = get_brreg_dic("nace", lang = lang),
    sector     = get_brreg_dic("sector", lang = lang)
  )
  if (dic %in% c("nace", "sector")) {
    stats::setNames(tbl$name, enc2utf8(tbl$code))
  } else {
    stats::setNames(tbl[[name_col]], enc2utf8(tbl$code))
  }
}


#' Fetch a brreg dictionary
#'
#' Retrieve English or Norwegian label dictionaries for NACE industry
#' codes (SSB classification 6, SN2007) or institutional sector codes
#' (SSB classification 39). Dictionaries are cached in a session-level
#' environment (following the eurostat package pattern), so the network
#' is consulted at most once per dictionary and language per session.
#'
#' @section Network access and offline use:
#' With `source = "auto"` (default) the dictionary is requested from the
#' SSB KLASS API (`data.ssb.no`), which is the only source of Norwegian
#' labels and of codes valid today. If the request fails, the bundled
#' English dictionary is returned instead and a
#' `tidybrreg_warning_bundled_fallback` states its vintage; for
#' `lang = "no"` there is no bundled fallback and the error propagates.
#' `source = "bundled"` never touches the network and is the mode to use
#' offline or in tests; `options(tidybrreg.offline = TRUE)` makes it the
#' default for the session. `source = "klass"` requires the network and
#' errors when it is unavailable. The bundled dictionaries were retrieved
#' from KLASS on 2026-06-16 (see [tidybrreg_provenance]).
#'
#' @param dictname One of `"nace"` or `"sector"`.
#' @param lang `"en"` (default) for English labels or `"no"` for
#'   Norwegian.
#' @param source One of `"auto"`, `"klass"`, or `"bundled"`; see the
#'   section on network access.
#' @param refresh Logical. If `TRUE`, ignore the session cache and
#'   fetch again.
#'
#' @returns A tibble with columns `code`, `name` (label in the requested
#'   language), and `level`. Attributes `source` (`"klass"` or
#'   `"bundled"`), `lang`, and `vintage` (the date the labels were
#'   retrieved from KLASS) record where the labels came from.
#'
#' @family tidybrreg utilities
#' @seealso [brreg_label()] for translating columns in place,
#'   [tidybrreg_provenance] for the bundled dictionaries' sources.
#' @export
#' @examples
#' get_brreg_dic("nace", source = "bundled")
#' attr(get_brreg_dic("sector", source = "bundled"), "vintage")
#' @examplesIf interactive() && curl::has_internet()
#' get_brreg_dic("nace", lang = "no")
get_brreg_dic <- function(dictname = c("nace", "sector"), lang = c("en", "no"),
                          source = c("auto", "klass", "bundled"),
                          refresh = FALSE) {
  dictname <- match.arg(dictname)
  lang <- match.arg(lang)
  source <- match.arg(source)
  if (source == "auto" && isTRUE(getOption("tidybrreg.offline", FALSE))) {
    source <- "bundled"
  }
  cache_key <- paste("dic", dictname, lang, source, sep = "_")

  if (!isTRUE(refresh) && exists(cache_key, envir = .brregEnv)) {
    return(get(cache_key, envir = .brregEnv))
  }

  result <- switch(source,
    bundled = bundled_dic(dictname, lang),
    klass   = klass_dic(dictname, lang),
    auto    = tryCatch(
      klass_dic(dictname, lang),
      error = \(e) {
        if (lang != "en") stop(e)
        fallback <- bundled_dic(dictname, lang)
        brreg_warn(c(
          "SSB KLASS unreachable; using the bundled {dictname} dictionary retrieved {format(attr(fallback, 'vintage'))}.",
          "i" = conditionMessage(e)
        ), class = "bundled_fallback", dictname = dictname,
        vintage = attr(fallback, "vintage"))
        fallback
      }
    )
  )

  assign(cache_key, result, envir = .brregEnv)
  result
}

#' The bundled dictionary (English only)
#' @keywords internal
bundled_dic <- function(dictname, lang) {
  if (lang != "en") {
    brreg_abort(c(
      "No bundled {.val {lang}} dictionary for {.val {dictname}}.",
      "i" = "Norwegian labels are available from SSB KLASS only; use {.code source = \"klass\"} with network access."
    ), class = "no_bundled_dictionary", dictname = dictname, lang = lang)
  }
  tbl <- switch(dictname, nace = nace_codes, sector = sector_codes)
  attr(tbl, "source") <- "bundled"
  attr(tbl, "lang") <- "en"
  tbl
}

#' Fetch a dictionary from SSB KLASS
#' @keywords internal
klass_dic <- function(dictname, lang) {
  classification_id <- switch(dictname, nace = 6L, sector = 39L)
  tbl <- fetch_klass(classification_id, lang = lang)
  attr(tbl, "source") <- "klass"
  attr(tbl, "lang") <- lang
  attr(tbl, "vintage") <- Sys.Date()
  tbl
}


#' KLASS language code for a tidybrreg `lang`
#' @keywords internal
klass_language <- function(lang) {
  if (identical(lang, "no")) "nb" else lang
}

#' Fetch classification labels from SSB Klass API
#' @param classification_id Integer. SSB Klass classification ID
#'   (6 = SN2007/NACE, 39 = institutional sector).
#' @param lang Language code: `"en"` or `"no"`. KLASS names its
#'   languages `en`, `nb` and `nn`; `"no"` is sent as `nb` (Bokmål).
#' @param date Date for which codes are valid.
#' @returns A tibble with columns `code`, `name`, `level`.
#' @keywords internal
fetch_klass <- function(classification_id, lang = "en", date = Sys.Date()) {
  resp <- klass_req(
    path  = paste0("classifications/", classification_id, "/codesAt"),
    query = list(date = format(date, "%Y-%m-%d"), language = klass_language(lang))
  ) |>
    httr2::req_perform()
  body <- httr2::resp_body_json(resp)
  dplyr::bind_rows(lapply(body$codes, \(c) tibble::tibble(
    code = as.character(c$code), name = as.character(c$name),
    level = as.character(c$level)
  )))
}
