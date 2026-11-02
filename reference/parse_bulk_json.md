# Parse a brreg bulk JSON download into a flat tibble

The `/enheter/lastned` and `/underenheter/lastned` endpoints return
gzipped JSON arrays with nested objects.
`jsonlite::fromJSON(flatten = TRUE)` expands nested objects to
dot-notation columns but leaves arrays as list columns. The array is
read in batches of complete objects
([`read_json_objects()`](https://sondreskarsten.github.io/tidybrreg/reference/read_json_objects.md))
and each batch parsed on its own, so the whole decoded tree is never in
memory at once; with a finite `n_max` only the first `n_max` elements
are read, which is how a sample of the register is parsed. Every list
column gets the tidy shape of the live path
([`collapse_observed()`](https://sondreskarsten.github.io/tidybrreg/reference/collapse_observed.md)):

## Usage

``` r
parse_bulk_json(path, type = "enheter", n_max = Inf)
```

## Arguments

- path:

  Path to the gzipped JSON file.

- type:

  Entity type (for column context).

- n_max:

  Maximum number of array elements to read (default: all).

## Value

A tibble mapped via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md);
arrays of objects are nested list-columns, everything else atomic.

## Details

- Character vectors (addresses, activities): line fragments of one
  value, joined with `"\n"`

- Data frames (`paategninger`, `historiskeNavn`): kept as a list-column
  of tibbles, one row per element, `NULL` where the entity has none

- Empty lists (HAL links): dropped

- NULL elements: `NA_character_`

Known columns are renamed via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).
Unknown columns pass through with auto-generated `snake_case` names
(zero-drop policy). The raw `.gz` file is the provenance fallback for
anyone needing the original nesting.
