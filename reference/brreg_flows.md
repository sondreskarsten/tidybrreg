# Compute daily entry and exit flows

Calculate daily counts of entity registrations (entries) and deletions
(exits) classified by industry (NACE code) and geography (municipality
code). Combines two data sources:

1.  **Bulk download** — the `registration_date` column provides the
    complete entry history for all currently-active entities. No exit
    information (deleted entities are purged from the nightly bulk
    export).

2.  **CDC stream** — `Ny` (new) and `Sletting` (deleted) events from the
    [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
    endpoint, enriched with entity attributes from the bulk data.
    Provides both entries and exits with real event timestamps.

When only bulk data is provided (no `updates`), only entries are
computed. Pass CDC data to unlock exit counts.

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
  or a snapshot. When `NULL` and a sync changelog exists, flows are
  computed from the changelog instead. Must contain `org_nr`,
  `registration_date`, `nace_1`, and `municipality_code` when provided.

- updates:

  Optional. A tibble from
  [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
  with CDC events. When provided, entries and exits from the CDC stream
  are enriched with attributes from `data` and merged with the
  registration-date-based entries.

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
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
# \donttest{
entities <- brreg_download()
#> ℹ Downloading full enheter register (~152 MB)
#> ✔ Downloading full enheter register (~152 MB) [3m 13.5s]
#> 
#> ✔ Downloaded 145.5 MB to cache.
flows <- brreg_flows(entities)

# With CDC exits
cdc <- brreg_updates(since = "2026-01-01", size = 10000)
flows <- brreg_flows(entities, updates = cdc)
# }
```
