# Save a dated snapshot of the full register

Download today's complete register and save as a Parquet partition in
the local snapshot store. Each call adds one partition to a
Hive-partitioned dataset at
`tools::R_user_dir("tidybrreg", "data")/{type}/snapshot_date={date}/`.
Subsequent calls to
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
and
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
query this partitioned dataset lazily via
[`arrow::open_dataset()`](https://arrow.apache.org/docs/r/reference/open_dataset.html).

## Usage

``` r
brreg_snapshot(
  type = c("enheter", "underenheter", "roller"),
  format = c("csv", "json"),
  date = Sys.Date(),
  force = FALSE,
  ask = interactive()
)
```

## Arguments

- type:

  One of `"enheter"` (main entities, default), `"underenheter"`
  (sub-entities / establishments), or `"roller"` (all roles for all
  entities, via `/roller/totalbestand`). Roller snapshots parse the
  nested JSON into a flat tibble matching
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
  output.

- format:

  Download format: `"csv"` (default for enheter/underenheter) or
  `"json"`. JSON captures additional fields not present in CSV (e.g.
  `kapital`, `vedtektsfestetFormaal`, `paategninger`). Roller is always
  JSON regardless of this parameter.

- date:

  Date for this snapshot (default: today). Used as the partition key,
  not as an API parameter — the brreg bulk endpoint always returns the
  current-day state.

- force:

  Logical. If `TRUE`, overwrite an existing partition for this date.
  Default `FALSE` skips if partition exists.

- ask:

  Logical. If `TRUE` (the default in interactive sessions), prompt
  before downloading ~145 MB.

## Value

The file path to the written Parquet partition (invisibly).

## See also

[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md)
to add historical snapshots from CSV files,
[`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)
to list available snapshots,
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
to construct panels from accumulated snapshots.

Other tidybrreg snapshot functions:
[`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md),
[`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md),
[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md),
[`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md),
[`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md),
[`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet() && tidybrreg:::parquet_tier() != "none"
# \donttest{
brreg_snapshot()
brreg_snapshots()
# }
}
```
