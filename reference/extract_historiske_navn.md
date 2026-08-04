# Extract historiskeNavn from JSON bulk entity data

The JSON bulk carries `historiskeNavn` inline as an array of
`{navn, fraDato, tilDato}` objects, serialized to a JSON string by
[`flatten_cell()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_cell.md)
under the auto-snake column `historiske_navn`. The CSV bulk has no such
column, so extraction there yields an empty table and history accrues
from the CDC feed instead.

## Usage

``` r
extract_historiske_navn(entities)
```

## Arguments

- entities:

  A tibble of bulk entity data with `org_nr`.
