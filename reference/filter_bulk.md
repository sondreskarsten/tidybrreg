# Filter bulk data by column values

Dispatches to Arrow pushdown filter or base R subsetting depending on
the object type. Arrow path reads only matching row groups from disk;
base R path scans the full in-memory tibble.

## Usage

``` r
filter_bulk(data, col, values, select = NULL)
```

## Arguments

- data:

  An Arrow Table or tibble.

- col:

  Column name to filter on.

- values:

  Character vector of values to match.

- select:

  Optional character vector of columns to keep.

## Value

A tibble (always materialized).
