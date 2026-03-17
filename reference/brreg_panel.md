# Construct a firm-period panel from accumulated snapshots

Build an unbalanced firm × period panel from the Hive-partitioned
snapshot store. For each target period, selects the most recent prior
snapshot (LOCF). Requires at least two snapshots saved via
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
or
[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md).

## Usage

``` r
brreg_panel(
  frequency = c("year", "quarter", "month", "custom"),
  cols = NULL,
  from = NULL,
  to = NULL,
  dates = NULL,
  type = c("enheter", "underenheter", "roller"),
  label = FALSE
)
```

## Arguments

- frequency:

  One of `"year"` (default), `"quarter"`, `"month"`, or `"custom"`. For
  `"custom"`, supply target dates via `dates`.

- cols:

  Character vector of column names to include. `NULL` (default) returns
  all columns mapped by
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).

- from, to:

  Start and end dates for the panel. `NULL` defaults to the range of
  available snapshots.

- dates:

  Date vector for `frequency = "custom"`.

- type:

  One of `"enheter"` or `"underenheter"`.

- label:

  Logical. If `TRUE`, apply
  [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
  to the result.

## Value

A tibble with columns: `org_nr`, `period` (character label for the
period), `snapshot_date` (the actual snapshot used), plus requested
`cols`. Attribute `date_mapping` records which snapshot was used for
each period.

## See also

[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
to accumulate snapshots,
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
for change detection between snapshots.

Other tidybrreg panel functions:
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md),
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("arrow", quietly = TRUE)
# \donttest{
# Annual panel of all entities
panel <- brreg_panel()

# Monthly panel for specific columns
panel <- brreg_panel("month", cols = c("employees", "nace_1", "legal_form"))
# }
}
```
