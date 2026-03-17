# Read the snapshot manifest

Returns the provenance catalog recording every download: endpoint,
timestamps, HTTP headers, file hashes, and CDC bridge metadata. The
manifest lives at `brreg_data_dir()/manifest.json`.

## Usage

``` r
brreg_manifest()
```

## Value

A tibble with one row per snapshot. Returns an empty tibble if no
manifest exists.

## See also

Other tidybrreg snapshot functions:
[`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md),
[`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md),
[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md),
[`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md),
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md),
[`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)

## Examples

``` r
brreg_manifest()
#> # A tibble: 0 × 13
#> # ℹ 13 variables: id <chr>, type <chr>, snapshot_date <date>, endpoint <chr>,
#> #   format <chr>, download_timestamp <dttm>, last_modified <chr>, etag <chr>,
#> #   file_hash <chr>, record_count <int>, raw_path <chr>, parquet_path <chr>,
#> #   cdc_bridge_first_update_id <int>
```
