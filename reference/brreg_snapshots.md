# List available snapshots

Scan the local snapshot store and return metadata for each partition.

## Usage

``` r
brreg_snapshots(type = c("enheter", "underenheter", "roller"))
```

## Arguments

- type:

  One of `"enheter"` or `"underenheter"`.

## Value

A tibble with columns: `snapshot_date` (Date), `file_size` (numeric,
bytes), `path` (character).

## See also

Other tidybrreg snapshot functions:
[`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md),
[`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md),
[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md),
[`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md),
[`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md),
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)

## Examples

``` r
brreg_snapshots()
#> # A tibble: 0 × 3
#> # ℹ 3 variables: snapshot_date <date>, file_size <dbl>, path <chr>
```
