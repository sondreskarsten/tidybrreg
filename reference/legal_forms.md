# Norwegian legal form codes with English translations

All organisasjonsformer registered with the Brønnøysund Register Centre,
with English translations. Fetched from the brreg API during package
build and supplemented with manual English translations.

## Usage

``` r
legal_forms
```

## Format

A tibble with 44 rows and 4 columns:

- code:

  Legal form code (e.g. `"AS"`, `"ASA"`, `"ENK"`).

- name_no:

  Norwegian description.

- expired:

  Date string if the form is expired, `NA` otherwise.

- name_en:

  English translation.

## See also

[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
to translate legal form codes in entity data.

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)

## Examples

``` r
legal_forms
#> # A tibble: 44 × 4
#>    code  name_no                                                 expired name_en
#>    <chr> <chr>                                                   <chr>   <chr>  
#>  1 AAFY  Underenhet til ikke-næringsdrivende                     NA      Establ…
#>  2 ADOS  Administrativ enhet - offentlig sektor                  NA      Admini…
#>  3 ANNA  Annen juridisk person                                   NA      Other …
#>  4 ANS   Ansvarlig selskap med solidarisk ansvar                 NA      Genera…
#>  5 AS    Aksjeselskap                                            NA      Privat…
#>  6 ASA   Allmennaksjeselskap                                     NA      Public…
#>  7 BA    Selskap med begrenset ansvar                            NA      Compan…
#>  8 BBL   Boligbyggelag                                           NA      Housin…
#>  9 BEDR  Underenhet til næringsdrivende og offentlig forvaltning NA      Establ…
#> 10 BO    Andre bo                                                NA      Other …
#> # ℹ 34 more rows
legal_forms[legal_forms$code == "AS", ]
#> # A tibble: 1 × 4
#>   code  name_no      expired name_en                
#>   <chr> <chr>        <chr>   <chr>                  
#> 1 AS    Aksjeselskap NA      Private limited company
```
