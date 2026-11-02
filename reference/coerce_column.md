# Coerce one column to a dictionary type, reporting failures

The single coercion rule shared by the live JSON path
([`coerce_types()`](https://sondreskarsten.github.io/tidybrreg/reference/coerce_types.md))
and the bulk path
([`rename_and_coerce()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_and_coerce.md)),
so a dictionary type is invariant across sources. A value that is
present (not `NA`, not empty) but does not parse is a failure; its index
is returned so the caller can build the `brreg_parse_problems` table. A
list-column (a nested array of objects) is returned unchanged: the
dictionary types describe scalar cells only.

## Usage

``` r
coerce_column(x, type)
```

## Arguments

- x:

  A vector.

- type:

  One of the
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
  types.

## Value

A list with `value` (the coerced vector) and `failed` (integer indices
of unparseable values).
