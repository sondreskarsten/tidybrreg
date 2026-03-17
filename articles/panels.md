# Building firm panels and time series

tidybrreg supports two paths for constructing firm-period panel data:
multi-snapshot diffing (comparing bulk downloads over time) and CDC
replay (applying incremental changes to a base snapshot). This vignette
covers both approaches.

## Accumulating snapshots

The snapshot engine stores dated bulk downloads as Hive-partitioned
Parquet files. Each call to
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
adds one partition.

``` r
library(tidybrreg)

# Save today's register (downloads ~152 MB, saves ~90 MB parquet)
brreg_snapshot("enheter")
brreg_snapshot("underenheter")
brreg_snapshot("roller")

# JSON format captures additional fields (share capital, articles)
brreg_snapshot("enheter", format = "json")
```

Each snapshot preserves both the processed Parquet file and the raw
`.gz` download for provenance. Check what’s available:

``` r
brreg_snapshots("enheter")
#> # A tibble: 12 × 3
#>    snapshot_date file_size path
#>    <date>            <dbl> <chr>
#>  1 2024-01-01     87654321 ~/.local/share/R/tidybrreg/enheter/...
#>  2 2024-02-01     87789012 ...
```

### Importing historical downloads

If you have historical CSV files from previous bulk downloads, import
them into the snapshot store:

``` r
csv_files <- list.files("~/brreg_archive/enheter/", full.names = TRUE)
for (f in csv_files) {
  date <- sub(".*_(\\d{4}-\\d{2}-\\d{2}).*", "\\1", f)
  brreg_import(f, snapshot_date = date, type = "enheter")
}
```

## Building panels from snapshots

[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
constructs firm × period panels. For each target period (year-end,
quarter-end, or month-end), it selects the most recent prior snapshot —
LOCF (last observation carried forward).

``` r
# Annual panel with selected variables
panel <- brreg_panel(
  frequency = "year",
  cols = c("employees", "nace_1", "legal_form", "municipality_code")
)
panel
#> # A tibble: 2,400,000 × 8
#>    org_nr    period     snapshot_date employees nace_1 legal_form is_entry is_exit
#>    <chr>     <chr>      <date>            <int> <chr>  <chr>      <lgl>    <lgl>
#>  1 810034882 2024-12-31 2024-07-01           10 47.110 AS         TRUE     FALSE
```

The `period` column labels the target date, while `snapshot_date`
records which actual snapshot was used. When a target date falls between
two snapshots, the earlier snapshot carries forward.

### Custom date targets

``` r
# Monthly panel
brreg_panel("month", cols = c("employees"))

# Specific dates
brreg_panel("custom",
  dates = as.Date(c("2024-03-31", "2024-09-30")),
  cols = c("employees", "nace_1")
)
```

### Entry and exit coding

[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
adds `is_entry` and `is_exit` columns:

- `is_entry = TRUE`: first period this entity appears in the panel
- `is_exit = TRUE`: last period this entity appears (or has
  `bankrupt = TRUE`)

For formal survival analysis, use
[`brreg_survival_data()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_survival_data.md)
which computes duration and censoring indicators.

## Detecting changes between snapshots

[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
compares two specific snapshots and returns entries, exits, and
field-level changes with both old and new values:

``` r
events <- brreg_events("2024-01-01", "2025-01-01")
events |> dplyr::count(event_type)
#>   event_type     n
#> 1 change     52314
#> 2 entry       8721
#> 3 exit        3102

# Which companies changed legal form?
events |>
  dplyr::filter(field == "legal_form") |>
  dplyr::select(org_nr, value_from, value_to)
#> # A tibble: 42 × 3
#>   org_nr    value_from value_to
#>   <chr>     <chr>      <chr>
#> 1 987654321 AS         ASA
```

This is the primary tool for tracking specific field changes, because it
gives both old and new values — unlike the CDC stream which only
provides new values.

## CDC replay: single snapshot + updates

When you have one base snapshot and want to reconstruct the register at
a later date without downloading again, replay CDC updates:

``` r
# Start with today's download
base <- brreg_download(type_output = "tibble")

# Fetch changes since the snapshot
updates <- brreg_updates(
  since = Sys.Date(),
  size = 10000,
  include_changes = TRUE
)

# Reconstruct state 30 days from now
future_state <- brreg_replay(base, updates, target_date = Sys.Date() + 30)

attr(future_state, "replay_info")
#> $n_insert: 312
#> $n_update: 1847
#> $n_delete: 45
```

### CDC limitations

- Field-level changes (`include_changes = TRUE`) are only available from
  September 2025.
- Before that date, only the change type (Ny/Endring/Sletting) is
  recorded.
- CDC patches contain only new values, not old values.
- Roller CDC (`type = "roller"`) reports only which entities changed,
  not the actual role data.

### Bridging snapshots to CDC

The manifest records the `Last-Modified` header from each download —
this is the data vintage date (when brreg regenerated the file):

``` r
manifest <- brreg_manifest()
manifest[, c("type", "snapshot_date", "last_modified")]
```

To bridge without gaps, fetch CDC updates starting 1 day before the
`Last-Modified` date. This creates deliberate overlap; deduplicate by
`org_nr` keeping the latest event.

## Aggregate time series

[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)
computes aggregate statistics from snapshots. Any variable, any summary
function, any grouping:

``` r
# Total employees by legal form per year
brreg_series(.vars = "employees", by = "legal_form")

# Multiple summary functions
brreg_series(
  .vars = "employees",
  .fns = list(avg = mean, total = sum, sd = sd),
  by = "nace_1",
  frequency = "quarter"
)

# Entity counts (default when .vars = NULL)
brreg_series(by = "legal_form")
```

Output columns are named `{variable}_{function}` (e.g. `employees_avg`,
`employees_total`).

## tsibble conversion

Convert panel or series output to tsibble for the tidyverts ecosystem
(fable, feasts, slider):

``` r
# Series → tsibble
ts <- brreg_series(.vars = "employees", by = "legal_form") |>
  as_brreg_tsibble()

# Panel → tsibble
panel_ts <- brreg_panel(cols = c("employees")) |>
  as_brreg_tsibble()
```

tsibble is created with `regular = FALSE` because brreg snapshots are
irregularly spaced. Use
[`tsibble::fill_gaps()`](https://tsibble.tidyverts.org/reference/fill_gaps.html) +
[`tidyr::fill()`](https://tidyr.tidyverse.org/reference/fill.html) for
LOCF imputation to a regular grid.

## Managing the snapshot store

``` r
# Where snapshots are stored
brreg_data_dir()

# Keep only the 12 most recent snapshots
brreg_cleanup(keep_n = 12)

# Delete snapshots older than 2 years
brreg_cleanup(max_age_days = 730)

# Open the full store as a lazy Arrow Dataset
ds <- brreg_open("enheter")
ds |>
  dplyr::filter(snapshot_date >= as.Date("2025-01-01"),
                legal_form == "AS") |>
  dplyr::select(org_nr, employees, snapshot_date) |>
  dplyr::collect()
```
