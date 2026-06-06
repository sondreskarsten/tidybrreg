# Backfill missing columns on legacy roller state

State files written before v0.3.4 lack `deregistered`, `ordering`,
`elected_by`, and `group_modified`. This function adds them as `NA` with
correct types so that
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md)
can compare old and new states without column mismatch errors.

## Usage

``` r
backfill_roller_cols(df)
```

## Arguments

- df:

  Roller state tibble (possibly missing columns).

## Value

The input with any missing columns added.
