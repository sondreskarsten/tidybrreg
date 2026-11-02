# Collapse an observed array value to one tidy cell

BRREG returns addresses, `vedtektsfestetFormaal`, and `aktivitet` as
arrays of register line-fragments of one value. Element text routinely
contains commas and semicolons but never newlines, so `"\n"` is the only
separator that survives a round trip: a consumer can split it back into
the observed elements, which `"; "` and `", "` do not allow. Arrays
whose elements are objects (`historiskeNavn`, `paategninger`) are
repeated observations of another unit and are nested instead: the cell
is a tibble with one row per element and one column per leaf of the
element, named in snake_case of the leaf's dot path, so the caller's
column is a list-column that
[`tidyr::unnest()`](https://tidyr.tidyverse.org/reference/unnest.html)
expands.

## Usage

``` r
collapse_observed(val)
```

## Arguments

- val:

  A list, atomic vector or data frame taken from a parsed response.

## Value

A length-1 character value, or a tibble for an array of objects.
