# Detect changes between two snapshots

Compare two dated snapshots and return a tibble of entity-level events:
entries (new entities), exits (deleted entities), and field-level
changes. Unlike the CDC stream, snapshot diffs provide both old and new
values for every changed field.

## Usage

``` r
brreg_events(
  date_from,
  date_to,
  cols = NULL,
  type = c("enheter", "underenheter")
)
```

## Arguments

- date_from, date_to:

  Dates identifying the two snapshots to compare. Both must exist in the
  snapshot store. `date_from` is the "before" state, `date_to` is the
  "after" state.

- cols:

  Character vector of columns to track for changes. `NULL` (default)
  tracks all columns in
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).

- type:

  One of `"enheter"` or `"underenheter"`.

## Value

A tibble with columns: `org_nr`, `event_type` (`"entry"`, `"exit"`,
`"change"`), `event_date` (the `date_to` snapshot date), `field` (column
name, `NA` for entry/exit), `value_from` (character, previous value),
`value_to` (character, new value).

## See also

[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
for the CDC stream (API-level changes),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
for full panel construction.

Other tidybrreg panel functions:
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("arrow", quietly = TRUE)
# \donttest{
snaps <- brreg_snapshots()
if (nrow(snaps) >= 2) {
  events <- brreg_events(snaps$snapshot_date[1], snaps$snapshot_date[2])
  events
}
# }
}
```
