# Annotation infotype codes with English descriptions

Maps brreg påtegning `infotype` codes to English descriptions. Used by
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md)
when `translate = TRUE`. Covers the infotype codes documented in the
brreg API reference (`"NAVN"`, `"FADR"`) and those observed in live data
(role codes used for missing-role annotations); unknown codes pass
through unchanged. Each annotation's own Norwegian text is available in
the `tekst` column of
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md)
output.

## Usage

``` r
annotation_infotypes
```

## Format

A tibble with 7 rows and 2 columns:

- code:

  Annotation infotype code (e.g. `"FADR"`, `"NAVN"`).

- name_en:

  English description.

## See also

[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md)
for the function that uses this table.

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)

## Examples

``` r
annotation_infotypes
#> # A tibble: 7 × 2
#>   code  name_en                            
#>   <chr> <chr>                              
#> 1 NAVN  Name annotation                    
#> 2 FADR  Business address presumed incorrect
#> 3 KONT  Missing contact person             
#> 4 DAGL  Missing general manager            
#> 5 FFØR  Missing business manager           
#> 6 REPR  Missing Norwegian representative   
#> 7 SAM   Incomplete co-owner information    
```
