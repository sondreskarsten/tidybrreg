# Parse the roller totalbestand gzipped JSON into a flat tibble

The `/roller/totalbestand` endpoint returns a gzipped JSON array where
each element is an entity with nested rollegrupper/roller structure,
identical to `/enheter/{orgnr}/roller`. This function reads the full
file, flattens all entities into one tibble matching
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
output.

## Usage

``` r
parse_roles_bulk(path)
```

## Arguments

- path:

  Path to the gzipped JSON file.

## Value

A tibble with one row per role assignment.
