# Shared test helpers for tidybrreg
# testthat automatically sources all helper-*.R files before tests

live_api_mode <- function() {
  identical(Sys.getenv("TIDYBRREG_LIVE_API"), "true")
}

#' Skip test if brreg API is not reachable
#' In live API mode (TIDYBRREG_LIVE_API=true), fails instead of skipping.
#' @keywords internal
skip_if_offline <- function() {
  skip_on_cran()
  tryCatch({
    httr2::request("https://data.brreg.no/enhetsregisteret/api") |>
      httr2::req_timeout(15) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()
  }, error = function(e) {
    if (live_api_mode()) {
      stop(paste("brreg API unreachable in live mode:", conditionMessage(e)))
    }
    skip("brreg API not reachable")
  })
}

#' Skip test unless TIDYBRREG_LIVE_API=true is set
#' Used in the live-api-tests.yaml workflow; skipped in normal CI
#' @keywords internal
skip_if_no_api <- function() {
  skip_on_cran()
  testthat::skip_if_offline(host = "data.brreg.no")
  if (!live_api_mode()) {
    skip("Set TIDYBRREG_LIVE_API=true to run live API tests")
  }
}

#' Wrap API calls so transient network errors skip instead of fail
#' In live API mode, all network errors are real failures.
#' @keywords internal
safely <- function(expr) {
  tryCatch(expr, error = function(e) {
    msgs <- paste(c(conditionMessage(e),
                     if (!is.null(e$parent)) conditionMessage(e$parent)),
                   collapse = " ")
    if (grepl("curl|connection|timeout|schannel|SSL|receive|reset|closed|Failure.*peer",
              msgs, ignore.case = TRUE)) {
      if (live_api_mode()) stop(e)
      skip(paste("Network error:", msgs))
    }
    stop(e)
  })
}
