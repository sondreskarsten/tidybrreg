# Read roller totalbestand JSON with best available parser

Dispatches to yyjsonr (7x faster, 70x less memory) when available,
falling back to jsonlite. Both produce nested lists compatible with
[`flatten_roles_bulk_fast()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles_bulk_fast.md).

## Usage

``` r
read_roles_json(path)
```

## Arguments

- path:

  Path to the gzipped JSON file.

## Value

A list of entity objects.
