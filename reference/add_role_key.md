# Derive holder_id and composite role_key

Adds `holder_id` and `role_key` columns. Person-held roles use
`person_id`; entity-held roles use `entity:{org_nr}`; roles with neither
get a positional fallback.

## Usage

``` r
add_role_key(df)
```

## Arguments

- df:

  Tibble from
  [`flatten_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles.md).

## Value

The input with `holder_id` and `role_key` appended.
