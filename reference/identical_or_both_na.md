# Vectorised NA-safe equality check

Returns `TRUE` where both values are `NA` or both are equal. Used in
diff filtering to exclude unchanged fields.

## Usage

``` r
identical_or_both_na(x, y)
```

## Arguments

- x, y:

  Character vectors of equal length.

## Value

Logical vector.
