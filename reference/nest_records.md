# Nest an array of objects as a tibble, one row per element

Each element is flattened with
[`flatten_json()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_json.md)
so nested objects inside an element become dot paths, then renamed to
snake_case. A data frame (the shape `jsonlite::fromJSON(flatten = TRUE)`
gives the bulk JSON) is taken as is. Values are kept as observed: the
field dictionary does not describe the leaves of these arrays, so no
type is asserted.

## Usage

``` r
nest_records(val)
```

## Arguments

- val:

  An unnamed list of named lists, or a data frame.

## Value

A tibble.
