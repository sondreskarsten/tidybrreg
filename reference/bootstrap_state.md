# Bootstrap state from bulk download

When `roller_method = "cdc"`, writes an empty roller state instead of
downloading the totalbestand (~125 MB compressed, ~3.4M rows). The CDC
method builds state incrementally via per-org
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
calls; full-register parse requires 32 GiB RAM.

## Usage

``` r
bootstrap_state(types, roller_method = "bulk", format = "csv", verbose = TRUE)
```

## Arguments

- types:

  Character vector of streams to bootstrap.

- roller_method:

  Passed from
  [`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md).

- format:

  Bulk download format passed to
  [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
  for enheter/underenheter. `"json"` additionally backfills the
  `historiske_navn` state from the inline `historiskeNavn` arrays; the
  CSV bulk carries no name history.

- verbose:

  Logical.
