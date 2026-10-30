#' Harmonize municipality codes across boundary reforms
#'
#' Remap `municipality_code` (kommunenummer) to the classification
#' valid at a target date, using correspondence tables from SSB's
#' KLASS system (classification 131). Handles the 2020 municipal
#' reform (428 → 356 municipalities) and 2024 county reversals.
#'
#' @param data A tibble with a municipality code column.
#' @param target_date Date. Remap all codes to the classification
#'   valid at this date. Default: today.
#' @param col Column name containing municipality codes. Default
#'   `"municipality_code"`.
#'
#' @returns The input tibble with two added columns:
#'   `{col}_harmonized` (the remapped code) and
#'   `{col}_target_name` (municipality name at the target date).
#'   Unmatched codes pass through unchanged.
#'
#' @family tidybrreg harmonization functions
#' @seealso [brreg_harmonize_nace()] for NACE code harmonization.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' # Remap old codes to current boundaries
#' df <- tibble::tibble(municipality_code = c("0301", "1201", "0602"))
#' brreg_harmonize_kommune(df)
#' }
brreg_harmonize_kommune <- function(data, target_date = Sys.Date(),
                                     col = "municipality_code") {
  rlang::check_installed("klassR", reason = "for municipality correspondence tables.")
  target_date <- as.Date(target_date)

  cache_key <- paste0("kommune_corr_", target_date)
  if (!exists(cache_key, envir = .brregEnv)) {
    corr <- tryCatch({
      klassR::GetKlass(131, date = target_date, output_style = "wide")
    }, error = \(e) {
      cli::cli_warn("Could not fetch municipality correspondence from SSB KLASS: {e$message}")
      return(data)
    })
    assign(cache_key, corr, envir = .brregEnv)
  } else {
    corr <- get(cache_key, envir = .brregEnv)
  }

  if (is.data.frame(corr) && "code" %in% names(corr) && "name" %in% names(corr)) {
    lkp_code <- stats::setNames(corr$code, corr$code)
    lkp_name <- stats::setNames(corr$name, corr$code)
  } else {
    return(data)
  }

  harmonized_col <- paste0(col, "_harmonized")
  name_col <- paste0(col, "_target_name")

  codes <- data[[col]]
  data[[harmonized_col]] <- ifelse(codes %in% names(lkp_code), lkp_code[codes], codes)
  data[[name_col]] <- ifelse(codes %in% names(lkp_name), lkp_name[codes], NA_character_)
  data
}


#' Harmonize NACE industry codes across classification revisions
#'
#' Remap NACE codes between SN2007 (NACE Rev. 2) and SN2025
#' (NACE Rev. 2.1) using SSB KLASS correspondence tables.
#'
#' @param data A tibble with a NACE code column.
#' @param from Source classification: `"SN2007"` (default) or
#'   `"SN2025"`.
#' @param to Target classification: `"SN2025"` (default) or
#'   `"SN2007"`.
#' @param col Column name containing NACE codes. Default `"nace_1"`.
#'
#' @returns The input tibble with `{col}_harmonized` (remapped code)
#'   and `{col}_ambiguous` (logical, `TRUE` when the mapping is
#'   one-to-many and the first match was used). Unmatched codes pass
#'   through unchanged.
#'
#' @family tidybrreg harmonization functions
#' @seealso [brreg_harmonize_kommune()] for municipality harmonization.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' df <- tibble::tibble(nace_1 = c("06.100", "64.190", "62.010"))
#' brreg_harmonize_nace(df, from = "SN2007", to = "SN2025")
#' }
brreg_harmonize_nace <- function(data, from = "SN2007", to = "SN2025",
                                  col = "nace_1") {
  rlang::check_installed("klassR", reason = "for NACE correspondence tables.")

  klass_ids <- c(SN2007 = 6L, SN2025 = 274L)
  from_id <- klass_ids[from]
  to_id <- klass_ids[to]
  if (is.na(from_id) || is.na(to_id)) {
    cli::cli_abort("Unknown classification. Use {.val SN2007} or {.val SN2025}.")
  }

  cache_key <- paste0("nace_corr_", from, "_", to)
  if (!exists(cache_key, envir = .brregEnv)) {
    corr <- tryCatch({
      klassR::GetKlass(klass = from_id, correspond = to_id)
    }, error = \(e) {
      cli::cli_warn("Could not fetch NACE correspondence from SSB KLASS: {e$message}")
      return(data)
    })
    assign(cache_key, corr, envir = .brregEnv)
  } else {
    corr <- get(cache_key, envir = .brregEnv)
  }

  if (!is.data.frame(corr)) return(data)

  source_col <- names(corr)[1]
  target_col <- names(corr)[2]

  dup_counts <- table(corr[[source_col]])
  ambiguous_codes <- names(dup_counts[dup_counts > 1])

  corr_first <- corr[!duplicated(corr[[source_col]]), ]
  lkp <- stats::setNames(corr_first[[target_col]], corr_first[[source_col]])

  codes <- data[[col]]
  harmonized_col <- paste0(col, "_harmonized")
  ambiguous_col <- paste0(col, "_ambiguous")

  data[[harmonized_col]] <- ifelse(codes %in% names(lkp), lkp[codes], codes)
  data[[ambiguous_col]] <- codes %in% ambiguous_codes
  data
}
