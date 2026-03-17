# Resolve local bulk data for network expansion

Returns the latest available data for each type, preferring parquet
snapshots (fast, pre-parsed) over download cache (raw, requires
re-parsing). With arrow installed, returns Arrow Tables for lazy
filtered reads (zero-copy memory map). Results are cached in the session
environment so repeated calls within the same R session do not re-read
from disk.

## Usage

``` r
resolve_bulk_data(types = c("enheter", "underenheter", "roller"))
```

## Arguments

- types:

  Character vector of types to resolve.

## Value

Named list of tibbles (or Arrow Tables).
