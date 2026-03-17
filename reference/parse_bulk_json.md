# Parse a brreg bulk JSON download into a flat tibble

The `/enheter/lastned` and `/underenheter/lastned` endpoints return
gzipped JSON arrays with nested objects.
`jsonlite::fromJSON(flatten = TRUE)` expands nested objects to
dot-notation columns but leaves arrays as list columns. This function
algorithmically flattens all list columns to atomic types:

## Usage

``` r
parse_bulk_json(path, type = "enheter")
```

## Arguments

- path:

  Path to the gzipped JSON file.

- type:

  Entity type (for column context).

## Value

A tibble with atomic columns only, mapped via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).

## Details

- Character vectors (addresses, activities): collapsed with separator

- Data frames (paategninger): serialized to JSON strings

- Empty lists (HAL links): dropped

- NULL elements: `NA_character_`

Known columns are renamed via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).
Unknown columns pass through with auto-generated `snake_case` names
(zero-drop policy). The raw `.gz` file is the provenance fallback for
anyone needing the original nesting.
