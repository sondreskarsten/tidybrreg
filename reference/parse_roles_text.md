# Decode one batch of roller entities with the best available parser

Dispatches to yyjsonr when available, falling back to jsonlite. Both
produce nested lists compatible with
[`flatten_roles_bulk_fast()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles_bulk_fast.md).

## Usage

``` r
parse_roles_text(text)
```

## Arguments

- text:

  JSON text of an array of entity objects.

## Value

A list of entity objects.
