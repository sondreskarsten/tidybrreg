# Rename columns via field_dict and coerce types

Shared between CSV and JSON parsing. Known dot-notation paths map to
English names; unknown paths get auto snake_case. Type coercion follows
`field_dict$type`. Parse failures are tracked and attached as a
`brreg_parse_problems` attribute.

## Usage

``` r
rename_and_coerce(dat)
```
