# Path to the sync state directory

Returns `brreg_data_dir()/state/`. Contains live state parquets, the
sync cursor, and the Hive-partitioned changelog.

## Usage

``` r
state_dir()
```

## Value

Character path (created if absent).
