# Flatten all patches from a page of CDC events in a single pass

No recursion. The brreg CDC nesting depth is bounded at 2 levels: object
-\> scalar, or object -\> array -\> scalar. Inlines the unpack for both
levels. Events with no `endringer` (Ny, Sletting, Fjernet) emit a single
synthetic row with `operation = NA`, `field = NA`, `new_value = NA`.

## Usage

``` r
flatten_page_patches(raw_updates)
```

## Arguments

- raw_updates:

  List of raw update objects from the API.

## Value

A flat tibble with update_id, org_nr, change_type, timestamp, operation,
field, new_value.
