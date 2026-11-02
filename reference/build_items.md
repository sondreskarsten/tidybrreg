# Build the line-item table of one filing

Build the line-item table of one filing

## Usage

``` r
build_items(flat)
```

## Arguments

- flat:

  Named list of the filing's statement leaves (dot paths).

## Value

A list with `items` (tibble), `failed` (indices of values that did not
parse as numbers) and `actual` (their raw text).
