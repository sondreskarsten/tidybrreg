# Give every list column its tidy shape

Dispatches on the runtime type of each list column's elements:
character/numeric vectors are collapsed, NULLs become `NA_character_`,
and a column whose elements are data frames stays a list-column of
tibbles (`NULL` where the entity has none). A list column with no
observed value at all (every array empty) is dropped, as an empty array
emits no key on the live path, so batches with and without the array
bind.

## Usage

``` r
flatten_list_columns(dat)
```

## Arguments

- dat:

  A tibble potentially containing list columns.

## Value

The same tibble with list columns converted to character or to
list-columns of tibbles.
