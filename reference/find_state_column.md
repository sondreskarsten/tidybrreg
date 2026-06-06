# Map a flattened CDC field name to a state column

Handles the many-to-one mapping from CDC patch paths to tidybrreg column
names. Uses `field_dict` when available, falls back to direct matching.

## Usage

``` r
find_state_column(cdc_field, state_cols)
```

## Arguments

- cdc_field:

  Character. The flattened field from `parse_patch`.

- state_cols:

  Character vector of column names in the state table.

## Value

Column name or `NULL` if no match.
