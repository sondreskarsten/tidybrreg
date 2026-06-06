# Extract påtegninger for flagged entities into a separate table

The enheter bulk download exposes påtegninger only as a boolean presence
flag (column `annotations` after
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
renaming). Annotation content is fetched per entity from the enheter
endpoint for the entities whose flag is true.

## Usage

``` r
extract_paategninger(entities)
```

## Arguments

- entities:

  A tibble of bulk entity data with `org_nr` and the `annotations`
  presence flag.
