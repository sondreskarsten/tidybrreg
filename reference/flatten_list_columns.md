# Algorithmically flatten all list columns to atomic types

Dispatches on the runtime type of each list column's elements:
character/numeric vectors are collapsed, data.frames are serialized to
JSON, NULLs become `NA_character_`.

## Usage

``` r
flatten_list_columns(dat)
```

## Arguments

- dat:

  A tibble potentially containing list columns.

## Value

The same tibble with all list columns converted to character.
