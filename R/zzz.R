#' Session-level dictionary cache (eurostat pattern)
#'
#' Holds dictionaries fetched from SSB KLASS by [get_brreg_dic()] for the
#' duration of the session, plus the HTTP metadata of the most recent
#' [brreg_download()]. Nothing is read from or written to disk at load
#' time; loading or attaching the package performs no network request
#' and creates no directory.
#' @keywords internal
.brregEnv <- new.env(parent = emptyenv())

# Suppress R CMD check NOTE for lazy-loaded datasets used in package functions
utils::globalVariables(c("legal_forms", "role_types", "role_groups",
                         "nace_codes", "sector_codes", "field_dict"))
