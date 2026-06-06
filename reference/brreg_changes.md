# Query the change log for field-level mutations

Returns a filtered view of all recorded changes across the four sync
streams: enheter, underenheter, roller, and påtegninger. Every call to
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
appends events to the changelog; this function reads and filters them.

## Usage

``` r
brreg_changes(
  track = NULL,
  registry = NULL,
  change_type = NULL,
  from = NULL,
  to = NULL,
  org_nr = NULL
)
```

## Arguments

- track:

  Character vector of fields to include (e.g.
  `c("nace_1", "municipality_code", "employees")`). `NULL` returns all
  fields.

- registry:

  Character vector of streams to include. Default includes all four.

- change_type:

  Character vector of event types to include. Options: `"entry"`,
  `"exit"`, `"change"`, `"annotation_added"`, `"annotation_cleared"`.

- from, to:

  Date range (inclusive).

- org_nr:

  Optional character vector of organisation numbers.

## Value

A tibble with columns: `timestamp`, `org_nr`, `registry`, `change_type`,
`field`, `value_from`, `value_to`, `update_id`.

## See also

[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to populate the changelog,
[`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md)
for aggregated entry/exit counts.

Other tidybrreg panel functions:
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md),
[`brreg_change_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_change_summary.md),
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) { # interactive()
# \donttest{
brreg_sync()

# All changes this month
brreg_changes(from = Sys.Date() - 30)

# NACE reclassifications only
brreg_changes(track = "nace_1", change_type = "change")

# Entries and exits for a specific entity
brreg_changes(org_nr = "923609016", change_type = c("entry", "exit"))

# All annotation events
brreg_changes(registry = "paategninger")
# }
}
```
