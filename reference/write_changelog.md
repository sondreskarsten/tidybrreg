# Append changelog entries to the Hive-partitioned store

Writes one parquet file per sync batch under
`changelog/sync_date={date}/batch-{time}.parquet`.

## Usage

``` r
write_changelog(changes, sync_date = Sys.Date())
```

## Arguments

- changes:

  A tibble with changelog rows.

- sync_date:

  Date for the partition key.
