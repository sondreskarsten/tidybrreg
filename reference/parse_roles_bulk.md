# Parse the roller totalbestand gzipped JSON into a flat tibble

The `/roller/totalbestand` endpoint returns a gzipped JSON array where
each element is an entity with nested rollegrupper/roller structure,
identical to `/enheter/{orgnr}/roller`. The array is streamed in batches
of complete entities by
[`read_json_objects()`](https://sondreskarsten.github.io/tidybrreg/reference/read_json_objects.md),
each batch is decoded and flattened by
[`flatten_roles_bulk_fast()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles_bulk_fast.md)
and the batches are bound with
[`bind_batches()`](https://sondreskarsten.github.io/tidybrreg/reference/bind_batches.md),
so the decoded tree of the whole register (several gigabytes as R lists)
is never in memory. The output matches
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md):
`resigned` is kept only when some role carried `fratraadt`, `NA` filled
as `FALSE`.

## Usage

``` r
parse_roles_bulk(path)
```

## Arguments

- path:

  Path to the gzipped JSON file.

## Value

A tibble with one row per role assignment.
