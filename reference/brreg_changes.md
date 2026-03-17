# Query the change log for field-level mutations

Returns a filtered view of all recorded changes across the four sync
streams: enheter, underenheter, roller, and påtegninger.

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

  Character vector of streams to include.

- change_type:

  Character vector of event types. Options: `"entry"`, `"exit"`,
  `"change"`, `"annotation_added"`, `"annotation_cleared"`.

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
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) { # interactive()
# \donttest{
brreg_sync()
brreg_changes(from = Sys.Date() - 30)
brreg_changes(track = "nace_1", change_type = "change")
# }
}
```
