#' Session-level dictionary cache (eurostat pattern)
#' @keywords internal
.brregEnv <- new.env(parent = emptyenv())

# Suppress R CMD check NOTE for lazy-loaded datasets used in package functions
utils::globalVariables(c("legal_forms", "role_types", "role_groups"))

#' @keywords internal
.onLoad <- function(libname, pkgname) {
  cache_dir <- tools::R_user_dir("tidybrreg", "data")

  nace_cache <- file.path(cache_dir, "nace_codes.rds")
  if (file.exists(nace_cache)) {
    cached <- tryCatch(readRDS(nace_cache), error = \(e) NULL)
    if (!is.null(cached)) {
      assign("nace_codes", cached, envir = parent.env(environment()))
    }
  }

  sector_cache <- file.path(cache_dir, "sector_codes.rds")
  if (file.exists(sector_cache)) {
    cached <- tryCatch(readRDS(sector_cache), error = \(e) NULL)
    if (!is.null(cached)) {
      assign("sector_codes", cached, envir = parent.env(environment()))
    }
  }
}

.onAttach <- function(libname, pkgname) {
  types <- c("enheter", "underenheter", "roller")
  found <- vapply(types, function(t) {
    nrow(brreg_snapshots(t)) > 0 || has_cached_download(t)
  }, logical(1))
  if (!all(found)) {
    missing <- types[!found]
    packageStartupMessage(
      "tidybrreg: bulk data not yet downloaded for: ",
      paste(missing, collapse = ", "), ".\n",
      "Run brreg_snapshot() for full network/panel support. ",
      "See ?brreg_status for details."
    )
  }
}
