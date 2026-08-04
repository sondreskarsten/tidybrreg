# Extract påtegninger from bulk entity data into a separate table

The CSV bulk exposes påtegninger only as a boolean presence flag (column
`annotations` after
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
renaming); annotation content is then fetched per entity from the
enheter endpoint for the entities whose flag is true. The JSON bulk
carries the full påtegning array inline, serialized to a JSON string by
[`flatten_cell()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_cell.md)
— detected by a leading `[` — and is parsed directly with no per-entity
fetches.

## Usage

``` r
extract_paategninger(entities)
```

## Arguments

- entities:

  A tibble of bulk entity data with `org_nr` and the `annotations` flag
  or serialized array.
