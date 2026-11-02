# Recursively flatten a patch value, calling emit() for each leaf

Recursively flatten a patch value, calling emit() for each leaf

## Usage

``` r
flatten_value_into(op, path_prefix, value, emit)
```

## Arguments

- emit:

  Function of `(op, path, value)` where `path` is the raw JSON pointer
  of the leaf.
