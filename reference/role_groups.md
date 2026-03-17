# Role group codes with English translations

Maps brreg rollegruppe codes to English names.

## Usage

``` r
role_groups
```

## Format

A tibble with 15 rows and 3 columns:

- code:

  Role group code (e.g. `"STYR"`, `"DAGL"`, `"REVI"`).

- name_en:

  English translation (e.g. `"Board of Directors"`).

- name_no:

  Norwegian description.

## See also

[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md).

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)

## Examples

``` r
role_groups
#> # A tibble: 15 × 3
#>    code  name_en                   name_no                         
#>    <chr> <chr>                     <chr>                           
#>  1 STYR  Board of Directors        Styre                           
#>  2 DAGL  Management                Daglig leder/adm.dir            
#>  3 REVI  Auditor                   Revisor                         
#>  4 REGN  Accountant                Regnskapsfører                  
#>  5 EIKM  Owner Municipalities      Eierkommuner                    
#>  6 KOMP  General Partners          Komplementarer                  
#>  7 DTPR  Partners (full liability) Deltakere med proratarisk ansvar
#>  8 DTSO  Partners (limited)        Deltakere med solidarisk ansvar 
#>  9 INNH  Proprietor                Innehaver                       
#> 10 KONT  Contact                   Kontaktperson                   
#> 11 BEST  Managing Shipowner        Bestyrende reder                
#> 12 BOBE  Bankruptcy Trustee        Bostyrer                        
#> 13 FFØR  Bookkeeper                Forretningsfører                
#> 14 SAM   Co-owners                 Sameiere                        
#> 15 HLSE  Health/Environment/Safety Helse, miljø og sikkerhet       
```
