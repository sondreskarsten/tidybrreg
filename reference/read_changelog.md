# Read changelog entries

Reads all or filtered changelog partitions. Uses
[`arrow::open_dataset()`](https://arrow.apache.org/docs/r/reference/open_dataset.html)
when available for partition pruning, falls back to reading individual
parquet files.

## Usage

``` r
read_changelog(from = NULL, to = NULL, registry = NULL, change_type = NULL)
```

## Arguments

- from, to:

  Optional date bounds.

- registry:

  Optional filter: `"enheter"`, `"underenheter"`, `"roller"`,
  `"paategninger"`.

- change_type:

  Optional filter: `"entry"`, `"exit"`, `"change"`, `"annotation"`.

## Value

A tibble of changelog rows.

## See also

Other tidybrreg data management functions:
[`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md),
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md),
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md),
[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md),
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md)
