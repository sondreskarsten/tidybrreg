# Apply roller CDC events via bulk totalbestand diff

Downloads the full roller totalbestand (~131 MB), parses it via
[`read_roles_json()`](https://sondreskarsten.github.io/tidybrreg/reference/read_roles_json.md) +
[`flatten_roles_bulk_fast()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles_bulk_fast.md),
and computes a field-level diff against stored state using
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md).
Roller CDC events are bare notifications (`rolle.oppdatert` with only
org_nr) — they carry no field-level changes, so the bulk diff is the
only way to determine what actually changed.

## Usage

``` r
apply_roller_events(state, updates, verbose = TRUE)
```

## Arguments

- state:

  Current roller state tibble (from previous sync).

- updates:

  Tibble of CDC events with `org_nr`, `timestamp`, `update_id`. Used for
  cursor advancement and per-org timestamp enrichment on the changelog.

- verbose:

  Logical. Print progress messages.

## Value

List with `state` (updated tibble) and `changelog` (field-level diff
tibble matching
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
schema).
