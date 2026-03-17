# Contributing to tidybrreg

Thank you for considering contributing to tidybrreg.

## Filing issues

- Use the [GitHub issue
  tracker](https://github.com/sondreskarsten/tidybrreg/issues).
- For bugs: include a minimal reproducible example and the output of
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html).
- For feature requests: describe the use case and the API endpoint
  involved.
- For API changes: include the URL and the actual vs expected response.

## Pull requests

1.  Fork and clone the repository.
2.  Create a branch: `git checkout -b feature/my-feature`.
3.  Install dev dependencies: `pak::pak(".", dependencies = TRUE)`.
4.  Make changes and add tests in `tests/testthat/`.
5.  Run `devtools::check()` — must pass with 0 errors and 0 warnings.
6.  Update `NEWS.md` with a bullet under the development version.
7.  Push and open a pull request.

## Code style

- Follow the [tidyverse style guide](https://style.tidyverse.org/).
- Use `|>` (base pipe), not `%>%`.
- Use
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  for errors with informative bullets.
- Gate optional dependencies with
  [`rlang::check_installed()`](https://rlang.r-lib.org/reference/is_installed.html).
- New exports need `@param`, `@returns`, `@export`, `@family`,
  `@examples`.

## Testing

``` r
devtools::test()                    # offline tests
Sys.setenv(NOT_CRAN = "true")
devtools::test()                    # includes API tests
```

API tests use a `safely()` wrapper that skips on network errors. Add
`skip_if_offline()` at the start of any new API test.

## Documentation

After changing roxygen comments or adding functions:

``` r
roxygen2::roxygenise()
rmarkdown::render("README.Rmd", output_format = "github_document")
```

## Code of conduct

This project follows the [Contributor Covenant Code of
Conduct](https://sondreskarsten.github.io/tidybrreg/CODE_OF_CONDUCT.md).
