# Bind parsed batches into one tibble, one column at a time

[`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
holds every batch and the bound result at once, so the peak is twice the
data. Binding column by column keeps one extra column alive instead:
each column is concatenated across the batches with
[`vctrs::vec_c()`](https://vctrs.r-lib.org/reference/vec_c.html) under
their common type, batches that did not carry the column (no entity in
them had the field) contribute a typed `NA` run, and the batches release
the column as soon as it is bound. List-columns of nested tibbles bind
as lists, `NULL` where the batch had no element. On the 1.1 million
entity register this takes about a fifth off the peak compared with
`bind_rows()`.

## Usage

``` r
bind_batches(batches)
```

## Arguments

- batches:

  A list of tibbles with compatible columns.

## Value

One tibble with the union of the columns.
