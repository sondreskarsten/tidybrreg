# Role type codes with English translations

Maps brreg rolle codes to English names. Used by
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
for automatic role labelling and by
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
for post-hoc translation.

## Usage

``` r
role_types
```

## Format

A tibble with 18 rows and 3 columns:

- code:

  Role code (e.g. `"LEDE"`, `"MEDL"`, `"DAGL"`).

- name_en:

  English translation (e.g. `"Chair of the Board"`).

- name_no:

  Norwegian description.

## See also

[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md).

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)

## Examples

``` r
role_types
#> # A tibble: 18 × 3
#>    code  name_en                     name_no                        
#>    <chr> <chr>                       <chr>                          
#>  1 LEDE  Chair of the Board          Styrets leder                  
#>  2 NEST  Deputy Chair                Nestleder                      
#>  3 MEDL  Board Member                Styremedlem                    
#>  4 VARA  Alternate Board Member      Varamedlem                     
#>  5 OBS   Observer                    Observatør                     
#>  6 DAGL  CEO / Managing Director     Daglig leder                   
#>  7 INNH  Sole Proprietor             Innehaver                      
#>  8 REVI  Auditor                     Revisor                        
#>  9 REGN  Accountant                  Regnskapsfører                 
#> 10 KONT  Contact Person              Kontaktperson                  
#> 11 DTPR  Partner (full liability)    Deltaker med proratarisk ansvar
#> 12 DTSO  Partner (limited liability) Deltaker med solidarisk ansvar 
#> 13 BEST  Managing Shipowner          Bestyrende reder               
#> 14 BOBE  Bankruptcy Trustee          Bostyrer                       
#> 15 KOMP  General Partner (KS)        Komplementar                   
#> 16 REPR  Norwegian Representative    Norsk representant             
#> 17 FFØR  Bookkeeper                  Forretningsfører               
#> 18 SAM   Co-owner                    Sameier                        
```
