# Recursively flatten nested JSON into dot-notation keys

Nested objects recurse into `parent.child` keys. Arrays are collapsed by
[`collapse_observed()`](https://sondreskarsten.github.io/tidybrreg/reference/collapse_observed.md):
arrays of strings to one newline-joined cell, arrays of objects to a
nested tibble. An empty array carries no observation and emits no key,
so a batch can bind entities with and without the array.

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
