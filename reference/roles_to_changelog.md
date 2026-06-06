# Convert role rows to long-format changelog entries

For entries (`change_type = "entry"`), each non-NA value field becomes a
row with `value_from = NA, value_to = value`. For exits, the reverse.

## Usage

``` r
roles_to_changelog(df, change_type, value_cols, timestamp, update_id)
```

## Arguments

- df:

  Keyed role tibble (with `role_key`, `holder_id`).

- change_type:

  One of `"entry"` or `"exit"`.

- value_cols:

  Character vector of field names to pivot.

- timestamp, update_id:

  Passed through to output.

## Value

A tibble in changelog schema.
