# Reconstruct register state by replaying CDC updates

Given a base snapshot and a stream of CDC updates from
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md),
reconstruct the state of the register at any arbitrary date. Uses
[`dplyr::rows_upsert()`](https://dplyr.tidyverse.org/reference/rows.html)
for Ny/Endring events and
[`dplyr::rows_delete()`](https://dplyr.tidyverse.org/reference/rows.html)
for Sletting events, applied chronologically.

## Usage

``` r
brreg_replay(base, updates, target_date = Sys.Date(), cols = NULL)
```

## Arguments

- base:

  A tibble from
  [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
  [`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md),
  or a snapshot read via
  [`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md).
  Must contain `org_nr`.

- updates:

  A tibble from
  [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
  with `include_changes = TRUE`. Must contain `org_nr`, `change_type`,
  `timestamp`, and `changes` (list-column of patch tibbles).

- target_date:

  Date. Reconstruct state as of this date. Only updates with
  `timestamp <= target_date` are applied.

- cols:

  Character vector of columns to track. If `NULL`, all columns present
  in `base` are used.

## Value

A tibble with the same columns as `base`, reflecting all applied changes
up to `target_date`. Attribute `replay_info` records the number of
inserts, updates, and deletes applied.

## Limitations

The brreg CDC stream provides only new values (not old values) in RFC
6902 JSON Patch format, and field-level changes are only available from
September 2025. Before that date, only the change type
(Ny/Endring/Sletting) is recorded — field-level replay is not possible
for those periods. Use
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
(snapshot diff) for pre-September 2025 field-level changes.

## See also

[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
for multi-snapshot panels,
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
to fetch the CDC stream.

Other tidybrreg panel functions:
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md),
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) {
base <- brreg_download(type_output = "tibble")
updates <- brreg_updates(since = Sys.Date() - 30,
                          size = 10000, include_changes = TRUE)
state <- brreg_replay(base, updates, target_date = Sys.Date())
}
```
