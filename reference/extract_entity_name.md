# Extract entity name from role JSON (parser-agnostic)

jsonlite returns `navn` as a named list (`$navnelinje1`). yyjsonr
collapses single-element objects to bare character. This handles both.

## Usage

``` r
extract_entity_name(navn)
```

## Arguments

- navn:

  The `enhet$navn` element from parsed role JSON.

## Value

Character scalar.
