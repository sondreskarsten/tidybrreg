#' Session-level dictionary cache (eurostat pattern)
#' @keywords internal
.brregEnv <- new.env(parent = emptyenv())

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
