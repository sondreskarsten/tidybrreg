# Recursively flatten nested JSON into dot-notation keys

Nested objects recurse into `parent.child` keys. Arrays are collapsed by
[`collapse_observed()`](https://sondreskarsten.github.io/tidybrreg/reference/collapse_observed.md).

## Usage

``` r
flatten_json(x, prefix = "")
```

## Arguments

- x:

  A parsed JSON list.

- prefix:

  Key prefix used during recursion.

## Value

A flat named list.
