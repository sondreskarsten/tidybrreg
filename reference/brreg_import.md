# Import a historical CSV as a snapshot partition

Read a brreg bulk CSV file (as downloaded by
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
or from the brreg website), normalize column names via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
and save as a dated Parquet partition in the snapshot store.

## Usage

``` r
brreg_import(
  path,
  snapshot_date,
  type = c("enheter", "underenheter", "roller"),
  force = FALSE
)
```

## Arguments

- path:

  Path to a brreg CSV file (gzipped or plain).

- snapshot_date:

  The date this CSV represents. Required — the CSV itself contains no
  date metadata.

- type:

  One of `"enheter"` or `"underenheter"`.

- force:

  Logical. Overwrite existing partition.

## Value

The file path to the written Parquet partition (invisibly).

## See also

[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
to download and save today's register.

Other tidybrreg snapshot functions:
[`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md),
[`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md),
[`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md),
[`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md),
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md),
[`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)

## Examples

``` r
if (FALSE) {
# Import a historical download
brreg_import("enheter_2024-12-31.csv.gz", snapshot_date = "2024-12-31")
}
```
