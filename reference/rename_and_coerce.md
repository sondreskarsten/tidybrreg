# Rename columns via field_dict and coerce types

Used by
[`parse_bulk_json()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_bulk_json.md).
Known dot-notation paths map to English names; unknown paths get auto
snake_case, made unique on collision. Type coercion follows
`field_dict$type` through
[`coerce_column()`](https://sondreskarsten.github.io/tidybrreg/reference/coerce_column.md),
the same rule the live path uses, so every dictionary type (including
`numeric`) is invariant across sources. Parse failures are attached as a
`brreg_parse_problems` attribute.

## Usage

``` r
rename_and_coerce(dat)
```
