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
#> # A tibble: 70 × 3
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
#> # ℹ 60 more rows
field_dict[field_dict$type == "Date", ]
#> # A tibble: 16 × 3
#>    api_path                                                   col_name     type 
#>    <chr>                                                      <chr>        <chr>
#>  1 stiftelsesdato                                             founding_da… Date 
#>  2 registreringsdatoEnhetsregisteret                          registratio… Date 
#>  3 konkursdato                                                bankruptcy_… Date 
#>  4 underAvviklingDato                                         liquidation… Date 
#>  5 registreringsdatoMerverdiavgiftsregisteret                 vat_registr… Date 
#>  6 registreringsdatoForetaksregisteret                        business_re… Date 
#>  7 registreringsdatoFrivillighetsregisteret                   nonprofit_r… Date 
#>  8 vedtektsdato                                               articles_da… Date 
#>  9 slettedato                                                 deletion_da… Date 
#> 10 datoEierskifte                                             ownership_c… Date 
#> 11 fravalgRevisjonDato                                        audit_exemp… Date 
#> 12 fravalgRevisjonBeslutningsDato                             audit_exemp… Date 
#> 13 registreringsdatoMerverdiavgiftsregisteretEnhetsregisteret vat_registr… Date 
#> 14 registreringsdatoAntallAnsatteEnhetsregisteret             employee_re… Date 
#> 15 registreringsdatoAntallAnsatteNavAaregisteret              employee_re… Date 
#> 16 oppstartsdato                                              start_date   Date 
```
