# Retrieve historical names (historiskeNavn) for entities

Norwegian entities keep their organization number across renames; the
register exposes prior names with the interval each was in force. BRREG
added the `historiskeNavn` field to enheter and underenheter on
2026-06-16. Name history accrues through
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md):
every rename in the CDC feed appends the superseded name here. History
predating your first sync exists only in the JSON bulk download and is
backfilled when bootstrapping with `brreg_sync(format = "json")`.

## Usage

``` r
brreg_historical_names(org_nr = NULL)
```

## Arguments

- org_nr:

  Optional character vector of organisation numbers. `NULL` returns all
  name history.

## Value

A tibble with columns: `org_nr`, `position` (array index), `name` (the
superseded name), `from_date`, `to_date` (register timestamps as
observed, format `"YYYY-MM-DD HH:MM:SS"`, kept as character).

## Details

Requires
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to have been run at least once to populate the local name-history state.

## See also

[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to populate name-history data,
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
with `registry = "historiske_navn"` to track rename events over time.

Other tidybrreg data management functions:
[`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md),
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md),
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md),
[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md),
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md),
[`read_changelog()`](https://sondreskarsten.github.io/tidybrreg/reference/read_changelog.md)

## Examples

``` r
if (FALSE) { # interactive()
# \donttest{
brreg_sync()
brreg_historical_names()
brreg_historical_names("923609016")
# }
}
```
