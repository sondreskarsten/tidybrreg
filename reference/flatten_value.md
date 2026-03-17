# Recursively flatten a patch value to leaf-level rows

Recursively flatten a patch value to leaf-level rows

## Usage

``` r
flatten_value(op, path_prefix, value)
```

## Arguments

- op:

  Character. The patch operation (`"replace"`, `"add"`).

- path_prefix:

  Character. The JSON Pointer path prefix (e.g. `"naeringskode1"`).

- value:

  The patch value. May be a scalar, a named list (JSON object), or an
  unnamed list (JSON array).

## Value

A tibble with columns `operation`, `field`, `new_value`.
