# Remove old snapshots from the local store

Delete snapshot partitions by count or age. At least one of `keep_n` or
`max_age_days` must be provided.

## Usage

``` r
brreg_cleanup(
  keep_n = NULL,
  max_age_days = NULL,
  type = c("enheter", "underenheter", "roller")
)
```

## Arguments

- keep_n:

  Integer. Keep the `keep_n` most recent snapshots and delete the rest.
  `NULL` to skip this criterion.

- max_age_days:

  Integer. Delete snapshots older than this many days. `NULL` to skip
  this criterion.

- type:

  One of `"enheter"` or `"underenheter"`.

## Value

A tibble of deleted snapshots (invisibly).

## See also

Other tidybrreg snapshot functions:
[`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md),
[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md),
[`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md),
[`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md),
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md),
[`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)

## Examples

``` r
if (FALSE) {
brreg_cleanup(keep_n = 12)
brreg_cleanup(max_age_days = 365)
}
```
