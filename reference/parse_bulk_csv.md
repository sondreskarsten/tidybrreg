# Parse a brreg bulk CSV into a tibble using the field dictionary

The bulk CSV uses `;` delimiter with `.` notation for nested fields
(e.g. `forretningsadresse.kommune`). This function reads all columns as
character, then applies
[`rename_and_coerce()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_and_coerce.md)
for field_dict mapping and type coercion — the same rename/coerce
pipeline used by
[`parse_bulk_json()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_bulk_json.md).

## Usage

``` r
parse_bulk_csv(path, type = "enheter", n_max = Inf)
```

## Arguments

- path:

  Path to the gzipped CSV file.

- type:

  Entity type for column selection.

- n_max:

  Maximum rows to read (default: all).

## Value

A tibble with columns mapped via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).
