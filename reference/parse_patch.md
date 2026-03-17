# Parse brreg flat JSON Patch array into a tibble

The brreg API returns field-level changes as a flat interleaved array:
`["replace", "/path", "value", "replace", "/path2", "value2", ...]`.

## Usage

``` r
parse_patch(endringer)
```

## Arguments

- endringer:

  List or character vector of patch operations.

## Value

A tibble with columns `operation`, `field`, `new_value`.
