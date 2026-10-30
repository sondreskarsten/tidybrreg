# Contributing to tidybrreg

Thank you for considering contributing to tidybrreg.

## Repository layout

Three packages live here and are versioned and built together:

| Package | Path | What belongs there |
|---|---|---|
| tidybrreg | `/` | One function per register endpoint, parsers, dictionaries. Exactly sixteen exports; CRAN-bound. Nothing that persists state. |
| tidybrregpanel | `tidybrregpanel/` | Snapshots, sync, replay, changelog, panels, series, networks: everything that keeps state on disk or derives quantities over time. |
| tidybrregmcp | `tidybrregmcp/` | The MCP server. It derives tools from tidybrreg's namespace and help pages, so per-tool code is almost always the wrong place for a change: fix the help page or the function in tidybrreg instead. `mcp_manifest()` writes the manifest the Node server is built from. |
| tidybrreg-mcp | `tidybrreg-mcp-node/` | The MCP server without R (npm). Its catalogue is `manifest.json`; regenerate it with `Rscript -e 'tidybrregmcp::mcp_manifest("tidybrreg-mcp-node/manifest.json")'` in a UTF-8 locale after any change to tidybrreg and commit it, or CI fails. Its TypeScript only ports the parsing rules; the endpoint contract comes from `inst/extdata/endpoints.json`, which tidybrreg's tests hold to the functions. |

A new endpoint wrapper goes in tidybrreg only if it is a thin, typed
call to one register endpoint; it then appears in the MCP server
automatically, and `tidybrregmcp/tests` will fail until its help page
documents every argument. Analytics go in tidybrregpanel.

## Filing issues

- Use the [GitHub issue tracker](https://github.com/sondreskarsten/tidybrreg/issues).
- For bugs: include a minimal reproducible example and the output of `sessionInfo()`.
- For feature requests: describe the use case and the API endpoint involved.
- For API changes: include the URL and the actual vs expected response.
- Weekly API drift reports land in one canonical `api-monitor` issue;
  accept the drift into the baseline by dispatching the `brreg API
  monitor` workflow with `update_baseline` and merging its PR.

## Pull requests

1. Fork and clone the repository.
2. Create a branch: `git checkout -b feature/my-feature`.
3. Install dev dependencies: `pak::pak(".", dependencies = TRUE)` (and the same in the companion directory you touch).
4. Make changes and add tests in `tests/testthat/`. Network calls are mocked with `local_brreg_responses()` from `tests/testthat/helper-mock.R`; the offline suite never reaches BRREG or SSB.
5. Run `devtools::check()` — must pass with 0 errors and 0 warnings. For tidybrreg also run `R CMD check --as-cran` on the built tarball.
6. Update `NEWS.md` with a bullet under the development version. tidybrregmcp's, tidybrregpanel's and tidybrreg-mcp-node's versions must equal tidybrreg's; a `v*` tag on main publishes the npm package and a GitHub release.
7. Push and open a pull request.

## Code style

- Follow the [tidyverse style guide](https://style.tidyverse.org/).
- Use `|>` (base pipe), not `%>%`.
- Signal conditions through `brreg_abort()` / `brreg_warn()` with a class listed in `?tidybrreg_conditions`; never return a silently partial result.
- Return typed zero-row tibbles for valid empty results.
- Parse dates with `parse_brreg_date()` and instants with `parse_brreg_instant()`; never `as.Date()` without a format or `as.POSIXct()` without `tz = "UTC"`.
- Gate optional dependencies with `rlang::check_installed()`.
- New exports need `@param`, `@returns`, `@export`, `@family`, `@examples`.

## Testing

```r
devtools::test()                    # offline tests (mocked)
Sys.setenv(NOT_CRAN = "true", TIDYBRREG_LIVE_API = "true")
devtools::test()                    # includes live API tests; outages fail
```

## Documentation

After changing roxygen comments or adding functions:

```r
roxygen2::roxygenise()
rmarkdown::render("README.Rmd", output_format = "github_document")
```

Bundled tables are regenerated with `data-raw/build_dictionaries.R`;
record the run date in `?tidybrreg_provenance`.

## Code of conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
