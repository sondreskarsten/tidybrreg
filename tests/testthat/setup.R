# Keep the offline test suite off the network: the bundled dictionaries
# serve brreg_label(). Live runs (TIDYBRREG_LIVE_API=true) use SSB KLASS.
if (!identical(Sys.getenv("TIDYBRREG_LIVE_API"), "true")) {
  withr::local_options(list(tidybrreg.offline = TRUE), .local_envir = testthat::teardown_env())
}
