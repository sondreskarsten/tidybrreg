# Resolve a single bulk dataset with session caching

Resolution order:

1.  Session cache in `.brregEnv` (keyed by type + snapshot date)

2.  Parquet snapshot — Arrow Table if arrow installed, else tibble

3.  Download cache — raw JSON/CSV parsed to tibble

## Usage

``` r
resolve_bulk(type)
```

## Arguments

- type:

  One of `"enheter"`, `"underenheter"`, `"roller"`.

## Value

An Arrow Table, tibble, or NULL if not available.

## Details

Arrow Tables are zero-copy memory maps (~0 bytes until filtered).
Tibbles from nanoparquet or raw cache load the full dataset eagerly (~2
GB for roller, ~1.5 GB for enheter).
