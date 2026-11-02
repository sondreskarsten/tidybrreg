# Check the accounting identities of one filing

Check the accounting identities of one filing

## Usage

``` r
check_identities(items)
```

## Arguments

- items:

  The filing's line-item table from
  [`build_items()`](https://sondreskarsten.github.io/tidybrreg/reference/build_items.md).

## Value

A list with `consistent` (logical, `NA` when nothing is checkable) and
`inconsistencies` (the failing names, zero-length when none fails).
