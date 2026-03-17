# Map target dates to nearest prior available snapshots (LOCF)

Map target dates to nearest prior available snapshots (LOCF)

## Usage

``` r
resolve_snapshot_dates(available, targets)
```

## Arguments

- available:

  Date vector of available snapshot dates.

- targets:

  Date vector of target dates.

## Value

A tibble with columns `target_date`, `period`, `snapshot_date`.
