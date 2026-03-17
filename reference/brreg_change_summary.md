# Summarize changes by field and type

Produces a count table of how many changes occurred per field and change
type.

## Usage

``` r
brreg_change_summary(from = NULL, to = NULL, registry = NULL)
```

## Arguments

- from, to:

  Date range (inclusive).

- registry:

  Character vector of streams to include.

## Value

A tibble with `registry`, `change_type`, `field`, `n`.

## See also

Other tidybrreg panel functions:
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)

## Examples

``` r
# \donttest{
brreg_change_summary(from = Sys.Date() - 7)
#> # A tibble: 0 × 4
#> # ℹ 4 variables: registry <chr>, change_type <chr>, field <chr>, n <int>
# }
```
