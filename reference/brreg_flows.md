# Compute daily entry and exit flows

Calculate daily counts of entity registrations (entries) and deletions
(exits) classified by industry (NACE code) and geography (municipality
code). Three data paths, selected automatically:

## Usage

``` r
brreg_flows(
  data = NULL,
  updates = NULL,
  by = c("nace_1", "municipality_code"),
  from = NULL,
  to = NULL,
  legal_form = NULL
)
```

## Arguments

- data:

  Optional. A tibble from
  [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
  or a snapshot. Required when no changelog exists. Must contain
  `org_nr`, `registration_date`, `nace_1`, and `municipality_code`.

- updates:

  Optional. A tibble from
  [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
  with CDC events.

- by:

  Character vector of grouping columns. Default
  `c("nace_1", "municipality_code")`. Use `NULL` for national totals, or
  any column present in `data`.

- from, to:

  Date range for the output. `NULL` defaults to the range of observed
  events.

- legal_form:

  Optional character vector of legal form codes to include (e.g.
  `c("AS", "ENK")`). `NULL` includes all.

## Value

A tibble with columns: `date` (Date), grouping columns from `by`,
`entries` (integer), `exits` (integer), `net` (integer: entries -
exits). An attribute `flow_source` records which data sources
contributed.

## Details

1.  **Changelog path** (preferred) — when
    [`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
    has been run, reads directly from the persistent changelog. Provides
    timestamped entries, exits, and field-level transitions. No
    arguments needed.

2.  **Bulk + CDC path** — pass `data` (from
    [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md))
    and optionally `updates` (from
    [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)).
    Registration dates provide historical entries; CDC provides recent
    entries + exits.

3.  **Bulk-only path** — pass `data` alone. Only entries are computed
    (no exit data available).

## Entry vs. founding date

This function uses `registration_date`
(registreringsdatoEnhetsregisteret), NOT `founding_date`
(stiftelsesdato). Registration date is when the entity entered the
registry. Founding date can precede registration by months (AS
companies) or years (associations).

## See also

[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
to get bulk data,
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
to get CDC events,
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)
for snapshot-based time series,
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md)
for tsibble conversion.

Other tidybrreg panel functions:
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md),
[`brreg_change_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_change_summary.md),
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md),
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# \donttest{
entities <- brreg_download()
flows <- brreg_flows(entities)

# With CDC exits
cdc <- brreg_updates(since = "2026-01-01", size = 10000)
flows <- brreg_flows(entities, updates = cdc)

# Monthly by NACE section
flows |>
  dplyr::mutate(month = format(date, "%Y-%m"),
                nace_section = substr(nace_1, 1, 2)) |>
  dplyr::summarise(entries = sum(entries), exits = sum(exits),
                   .by = c(month, nace_section))
# }
}
```
