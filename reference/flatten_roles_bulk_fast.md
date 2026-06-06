# Vectorised bulk flatten of roller totalbestand

Two-pass approach: first counts total roles across all entities to
pre-allocate vectors, then fills by index. Avoids per-row list
construction and the O(n^2) cost of incremental `bind_rows()` on
thousands of small tibbles.

## Usage

``` r
flatten_roles_bulk_fast(entities)
```

## Arguments

- entities:

  List of entity objects from
  [`read_roles_json()`](https://sondreskarsten.github.io/tidybrreg/reference/read_roles_json.md).

## Value

A tibble matching
[`flatten_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles.md)
output schema.
