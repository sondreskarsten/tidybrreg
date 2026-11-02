# Regnskap line items with English and Norwegian labels

One row per line item of the filing, keyed by the `item` code that
[regnskap_dict](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md)
assigns to each statement leaf.
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
translates the `item` column of
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md)'s
`items` table to `name_en` or `name_no`, as
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
does for role codes.

## Usage

``` r
regnskap_items
```

## Format

A tibble with 31 rows and 3 columns:

- code:

  Item code used in package output (e.g. `"total_assets"`,
  `"net_income"`).

- name_en:

  English label.

- name_no:

  Norwegian label, the presentation-plan caption.

## Source

Package-authored; see
[tidybrreg_provenance](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md).

## See also

[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[regnskap_dict](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md),
[regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md).

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`regnskap_dict`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md),
[`regnskap_groups`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md),
[`tidybrreg_provenance`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md)

## Examples

``` r
regnskap_items
#> # A tibble: 31 × 3
#>    code                     name_en                      name_no                
#>    <chr>                    <chr>                        <chr>                  
#>  1 total_equity_liabilities Total equity and liabilities Sum egenkapital og gje…
#>  2 total_equity             Total equity                 Sum egenkapital        
#>  3 paid_in_equity           Paid-in equity               Sum innskutt egenkapit…
#>  4 retained_equity          Retained earnings            Sum opptjent egenkapit…
#>  5 total_liabilities        Total liabilities            Sum gjeld              
#>  6 current_liabilities      Current liabilities          Sum kortsiktig gjeld   
#>  7 long_term_liabilities    Long-term liabilities        Sum langsiktig gjeld   
#>  8 total_assets             Total assets                 Sum eiendeler          
#>  9 current_assets           Current assets               Sum omløpsmidler       
#> 10 fixed_assets             Fixed assets                 Sum anleggsmidler      
#> # ℹ 21 more rows
brreg_label(c("total_assets", "net_income"), dic = "regnskap_item", lang = "no")
#> [1] "Sum eiendeler" "Årsresultat"  
```
