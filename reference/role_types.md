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

A tibble with 24 rows and 3 columns:

- code:

  Role code (e.g. `"LEDE"`, `"MEDL"`, `"DAGL"`).

- name_en:

  English translation (e.g. `"Chair of the Board"`).

- name_no:

  Norwegian description.

## Source

Package-authored from BRREG documentation; see
[tidybrreg_provenance](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md).

## See also

[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md).

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`regnskap_dict`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md),
[`regnskap_groups`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md),
[`regnskap_items`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[`tidybrreg_provenance`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md)

## Examples

``` r
role_types
#> # A tibble: 24 × 3
#>    code  name_en                 name_no       
#>    <chr> <chr>                   <chr>         
#>  1 LEDE  Chair of the Board      Styrets leder 
#>  2 NEST  Deputy Chair            Nestleder     
#>  3 MEDL  Board Member            Styremedlem   
#>  4 VARA  Alternate Board Member  Varamedlem    
#>  5 OBS   Observer                Observatør    
#>  6 DAGL  CEO / Managing Director Daglig leder  
#>  7 INNH  Sole Proprietor         Innehaver     
#>  8 REVI  Auditor                 Revisor       
#>  9 REGN  Accountant              Regnskapsfører
#> 10 KONT  Contact Person          Kontaktperson 
#> # ℹ 14 more rows
```
