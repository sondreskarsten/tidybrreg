# Write a data frame to parquet atomically

Writes to a temporary file first, then renames to the target path.
Dispatches to arrow or nanoparquet depending on availability.

## Usage

``` r
write_parquet_safe(df, path)
```

## Arguments

- df:

  A data frame.

- path:

  Target file path.
