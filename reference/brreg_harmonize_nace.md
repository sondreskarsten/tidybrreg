# Harmonize NACE industry codes across classification revisions

Remap NACE codes between SN2007 (NACE Rev. 2) and SN2025 (NACE Rev. 2.1)
using SSB KLASS correspondence tables.

## Usage

``` r
brreg_harmonize_nace(data, from = "SN2007", to = "SN2025", col = "nace_1")
```

## Arguments

- data:

  A tibble with a NACE code column.

- from:

  Source classification: `"SN2007"` (default) or `"SN2025"`.

- to:

  Target classification: `"SN2025"` (default) or `"SN2007"`.

- col:

  Column name containing NACE codes. Default `"nace_1"`.

## Value

The input tibble with `{col}_harmonized` (remapped code) and
`{col}_ambiguous` (logical, `TRUE` when the mapping is one-to-many and
the first match was used). Unmatched codes pass through unchanged.

## See also

[`brreg_harmonize_kommune()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_kommune.md)
for municipality harmonization.

Other tidybrreg harmonization functions:
[`brreg_harmonize_kommune()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_kommune.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# \donttest{
df <- tibble::tibble(nace_1 = c("06.100", "64.190", "62.010"))
brreg_harmonize_nace(df, from = "SN2007", to = "SN2025")
# }
}
```
