# Parse brreg RFC 6902 JSON Patch operations into a tibble

The brreg CDC endpoint returns `endringer` as a list of patch objects,
each with `op`, `path`, and optionally `value`. Values may be scalars or
nested objects (e.g. the full `naeringskode1` or `forretningsadresse`
object). Nested objects are flattened to leaf-level rows so that
`/naeringskode1` with value `{kode: "43.210", beskrivelse: "..."}`
produces two rows: `naeringskode1_kode` and `naeringskode1_beskrivelse`.

## Usage

``` r
parse_patch(endringer)
```

## Arguments

- endringer:

  List of patch operations from the brreg API.

## Value

A tibble with columns `operation`, `field`, `new_value`. All `new_value`
entries are character. Array-index suffixes (e.g. `adresse_0`) are
preserved.
