# Open the snapshot store as a lazy Arrow Dataset

Returns an Arrow Dataset with Hive-style partitioning on
`snapshot_date`. No data is loaded until
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html).
Requires the arrow package.

## Usage

``` r
brreg_open(type = c("enheter", "underenheter", "roller"))
```

## Arguments

- type:

  One of `"enheter"` or `"underenheter"`.

## Value

An
[`arrow::Dataset`](https://arrow.apache.org/docs/r/reference/Dataset.html)
object.

## See also

[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
for the higher-level panel constructor.

Other tidybrreg snapshot functions:
[`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md),
[`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md),
[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md),
[`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md),
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md),
[`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("arrow", quietly = TRUE)
ds <- brreg_open()
ds
}
```
