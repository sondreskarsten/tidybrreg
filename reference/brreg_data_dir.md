# Path to the tidybrreg snapshot store

Returns (and creates if needed) the directory where tidybrreg stores
Parquet snapshots. Location follows R's standard user data directory
convention via `tools::R_user_dir("tidybrreg", "data")`. Override with
`options(brreg.data_dir = "/custom/path")`.

## Usage

``` r
brreg_data_dir()
```

## Value

Character path.

## See also

Other tidybrreg snapshot functions:
[`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md),
[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md),
[`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md),
[`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md),
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md),
[`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)

## Examples

``` r
brreg_data_dir()
#> [1] "/home/runner/.local/share/R/tidybrreg"
```
