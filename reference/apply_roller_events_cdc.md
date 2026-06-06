# Apply roller CDC events via per-org API re-fetch (legacy fallback)

Fetches current roles for each affected org via
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md).
Produces field-level changelogs using
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md)
on a per-org basis. Slower than
[`apply_roller_events()`](https://sondreskarsten.github.io/tidybrreg/reference/apply_roller_events.md)
(bulk method) but provides per-event timestamp attribution for sub-daily
syncs.

## Usage

``` r
apply_roller_events_cdc(state, updates, verbose = TRUE)
```

## Arguments

- state:

  Current roller state tibble.

- updates:

  Tibble of CDC events with `org_nr`, `timestamp`, `update_id`.

- verbose:

  Logical.

## Value

List with `state` and `changelog`.
