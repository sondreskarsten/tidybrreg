# Field dictionary: Norwegian API paths to English column names

A tibble mapping brreg JSON field paths to English column names and R
types. Used internally by the parse engine. API fields absent from this
dictionary pass through with auto-generated snake_case names rather than
being silently dropped.

## Usage

``` r
field_dict
```

## Format

A tibble with 49 rows and 3 columns:

- api_path:

  Dot-notation path in the brreg JSON response (e.g.
  `"organisasjonsnummer"`, `"forretningsadresse.kommune"`).

- col_name:

  English column name used in package output (e.g. `"org_nr"`,
  `"municipality"`).

- type:

  R type for coercion: `"character"`, `"Date"`, `"integer"`, or
  `"logical"`.

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for the function that uses this dictionary.

Other tidybrreg reference data:
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)

## Examples

``` r
field_dict
#> # A tibble: 49 × 3
#>    api_path                          col_name           type     
#>    <chr>                             <chr>              <chr>    
#>  1 organisasjonsnummer               org_nr             character
#>  2 navn                              name               character
#>  3 organisasjonsform.kode            legal_form         character
#>  4 organisasjonsform.beskrivelse     legal_form_desc    character
#>  5 stiftelsesdato                    founding_date      Date     
#>  6 registreringsdatoEnhetsregisteret registration_date  Date     
#>  7 antallAnsatte                     employees          integer  
#>  8 harRegistrertAntallAnsatte        employees_reported logical  
#>  9 hjemmeside                        website            character
#> 10 naeringskode1.kode                nace_1             character
#> # ℹ 39 more rows
field_dict[field_dict$type == "Date", ]
#> # A tibble: 8 × 3
#>   api_path                                   col_name                type 
#>   <chr>                                      <chr>                   <chr>
#> 1 stiftelsesdato                             founding_date           Date 
#> 2 registreringsdatoEnhetsregisteret          registration_date       Date 
#> 3 konkursdato                                bankruptcy_date         Date 
#> 4 underAvviklingDato                         liquidation_date        Date 
#> 5 registreringsdatoMerverdiavgiftsregisteret vat_registration_date   Date 
#> 6 registreringsdatoForetaksregisteret        business_register_date  Date 
#> 7 registreringsdatoFrivillighetsregisteret   nonprofit_register_date Date 
#> 8 vedtektsdato                               articles_date           Date 
```
