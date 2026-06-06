# Diff fields on roles that exist in both old and new state

Joins on `role_key`, casts all value columns to character, and detects
field-level changes including NA transitions.

## Usage

``` r
diff_common_roles(old_df, new_df, value_cols, timestamp, update_id)
```

## Arguments

- old_df, new_df:

  Keyed role tibbles filtered to common keys.

- value_cols:

  Fields to compare.

- timestamp, update_id:

  Passed through.

## Value

Tibble in changelog schema (only rows where values differ).
