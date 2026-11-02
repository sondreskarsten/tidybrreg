# Rename fields using field_dict; pass through unmapped fields

Only observed fields are emitted. Should two distinct observed paths map
to one dictionary target, the first path in dictionary order fills it
and the second falls back to its auto-generated snake_case name, keeping
its dictionary type, so no observed value is lost. Unmapped paths whose
snake_case names collide are made unique with a numeric suffix.

## Usage

``` r
rename_from_dict(flat, dict = field_dict)
```

## Arguments

- flat:

  A flat named list from
  [`flatten_json()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_json.md).

- dict:

  The field map to apply:
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
  (default) or `regnskap_dict`.
