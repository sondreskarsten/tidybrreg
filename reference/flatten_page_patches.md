# Flatten all patches from a page of CDC events

One row per patch leaf via
[`parse_patch()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_patch.md),
so nesting of any depth is handled identically to the `changes`
list-column of
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md).
Events with no `endringer` emit one synthetic row.

## Usage

``` r
flatten_page_patches(raw_updates)
```

## Arguments

- raw_updates:

  List of raw update objects from the API.

## Value

A flat tibble; see
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md).
