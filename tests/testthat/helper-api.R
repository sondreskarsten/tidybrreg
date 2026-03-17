# Shared test helpers for tidybrreg
# testthat automatically sources all helper-*.R files before tests

#' Skip test if brreg API is not reachable
#' @keywords internal
skip_if_offline <- function() {
  skip_on_cran()
  tryCatch({
    httr2::request("https://data.brreg.no") |>
      httr2::req_method("HEAD") |>
      httr2::req_timeout(10) |>
      httr2::req_perform()
  }, error = function(e) skip("brreg API not reachable"))
}

#' Skip test unless TIDYBRREG_LIVE_API=true is set
#' Used in the live-api-tests.yaml workflow; skipped in normal CI
#' @keywords internal
skip_if_no_api <- function() {
  skip_on_cran()
  testthat::skip_if_offline(host = "data.brreg.no")
  if (!identical(Sys.getenv("TIDYBRREG_LIVE_API"), "true")) {
    skip("Set TIDYBRREG_LIVE_API=true to run live API tests")
  }
}

#' Wrap API calls so transient network errors skip instead of fail
#' httr2 wraps curl errors via rlang::abort(parent=), so the actual
#' curl/schannel message lives in e$parent$message, not e$message.
#' @keywords internal
safely <- function(expr) {
  tryCatch(expr, error = function(e) {
    msgs <- paste(c(conditionMessage(e),
                     if (!is.null(e$parent)) conditionMessage(e$parent)),
                   collapse = " ")
    if (grepl("curl|connection|timeout|schannel|SSL|receive|reset|closed|Failure.*peer",
              msgs, ignore.case = TRUE)) {
      skip(paste("Network error:", msgs))
    }
    stop(e)
  })
}
