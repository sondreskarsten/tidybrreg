# Harmonize municipality codes across boundary reforms

Remap `municipality_code` (kommunenummer) to the classification valid at
a target date, using correspondence tables from SSB's KLASS system
(classification 131). Handles the 2020 municipal reform (428 → 356
municipalities) and 2024 county reversals.

## Usage

``` r
brreg_harmonize_kommune(
  data,
  target_date = Sys.Date(),
  col = "municipality_code"
)
```

## Arguments

- data:

  A tibble with a municipality code column.

- target_date:

  Date. Remap all codes to the classification valid at this date.
  Default: today.

- col:

  Column name containing municipality codes. Default
  `"municipality_code"`.

## Value

The input tibble with two added columns: `{col}_harmonized` (the
remapped code) and `{col}_target_name` (municipality name at the target
date). Unmatched codes pass through unchanged.

## See also

[`brreg_harmonize_nace()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_nace.md)
for NACE code harmonization.

Other tidybrreg harmonization functions:
[`brreg_harmonize_nace()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_nace.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# \donttest{
# Remap old codes to current boundaries
df <- tibble::tibble(municipality_code = c("0301", "1201", "0602"))
brreg_harmonize_kommune(df)
# }
}
```
