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
#>                                      api_path                   col_name
#> 1                         organisasjonsnummer                     org_nr
#> 2                                        navn                       name
#> 3                      organisasjonsform.kode                 legal_form
#> 4               organisasjonsform.beskrivelse            legal_form_desc
#> 5                              stiftelsesdato              founding_date
#> 6           registreringsdatoEnhetsregisteret          registration_date
#> 7                               antallAnsatte                  employees
#> 8                  harRegistrertAntallAnsatte         employees_reported
#> 9                                  hjemmeside                    website
#> 10                         naeringskode1.kode                     nace_1
#> 11                  naeringskode1.beskrivelse                nace_1_desc
#> 12                         naeringskode2.kode                     nace_2
#> 13                  naeringskode2.beskrivelse                nace_2_desc
#> 14                         naeringskode3.kode                     nace_3
#> 15                  naeringskode3.beskrivelse                nace_3_desc
#> 16              institusjonellSektorkode.kode                sector_code
#> 17       institusjonellSektorkode.beskrivelse                sector_desc
#> 18                 forretningsadresse.adresse           business_address
#> 19              forretningsadresse.postnummer          business_postcode
#> 20                forretningsadresse.poststed              business_city
#> 21           forretningsadresse.kommunenummer          municipality_code
#> 22                 forretningsadresse.kommune               municipality
#> 23                forretningsadresse.landkode               country_code
#> 24                    forretningsadresse.land                    country
#> 25                        postadresse.adresse             postal_address
#> 26                     postadresse.postnummer            postal_postcode
#> 27                       postadresse.poststed                postal_city
#> 28                  postadresse.kommunenummer   postal_municipality_code
#> 29                        postadresse.kommune        postal_municipality
#> 30                       postadresse.landkode        postal_country_code
#> 31                           postadresse.land             postal_country
#> 32                beliggenhetsadresse.adresse           location_address
#> 33             beliggenhetsadresse.postnummer          location_postcode
#> 34               beliggenhetsadresse.poststed              location_city
#> 35          beliggenhetsadresse.kommunenummer location_municipality_code
#> 36                beliggenhetsadresse.kommune      location_municipality
#> 37               beliggenhetsadresse.landkode      location_country_code
#> 38                   beliggenhetsadresse.land           location_country
#> 39          utenlandskRegisterAdresse.adresse        foreign_reg_address
#> 40             utenlandskRegisterAdresse.land        foreign_reg_country
#> 41         utenlandskRegisterAdresse.poststed           foreign_reg_city
#> 42                                    konkurs                   bankrupt
#> 43                                konkursdato            bankruptcy_date
#> 44                             underAvvikling             in_liquidation
#> 45                         underAvviklingDato           liquidation_date
#> 46  underTvangsavviklingEllerTvangsopplosning         forced_dissolution
#> 47                   registrertIMvaregisteret             vat_registered
#> 48 registreringsdatoMerverdiavgiftsregisteret      vat_registration_date
#> 49              registrertIForetaksregisteret       in_business_register
#> 50        registreringsdatoForetaksregisteret     business_register_date
#> 51         registrertIFrivillighetsregisteret      in_nonprofit_register
#> 52   registreringsdatoFrivillighetsregisteret    nonprofit_register_date
#> 53            registrertIStiftelsesregisteret     in_foundation_register
#> 54                            overordnetEnhet              parent_org_nr
#> 55                                 erIKonsern         in_corporate_group
#> 56                      vedtektsfestetFormaal                    purpose
#> 57                               vedtektsdato              articles_date
#> 58                 sisteInnsendteAarsregnskap       last_annual_accounts
#> 59                                   maalform              language_form
#> 60                                  aktivitet                   activity
#> 61                                 slettedato              deletion_date
#> 62                             datoEierskifte      ownership_change_date
#>         type
#> 1  character
#> 2  character
#> 3  character
#> 4  character
#> 5       Date
#> 6       Date
#> 7    integer
#> 8    logical
#> 9  character
#> 10 character
#> 11 character
#> 12 character
#> 13 character
#> 14 character
#> 15 character
#> 16 character
#> 17 character
#> 18 character
#> 19 character
#> 20 character
#> 21 character
#> 22 character
#> 23 character
#> 24 character
#> 25 character
#> 26 character
#> 27 character
#> 28 character
#> 29 character
#> 30 character
#> 31 character
#> 32 character
#> 33 character
#> 34 character
#> 35 character
#> 36 character
#> 37 character
#> 38 character
#> 39 character
#> 40 character
#> 41 character
#> 42   logical
#> 43      Date
#> 44   logical
#> 45      Date
#> 46   logical
#> 47   logical
#> 48      Date
#> 49   logical
#> 50      Date
#> 51   logical
#> 52      Date
#> 53   logical
#> 54 character
#> 55   logical
#> 56 character
#> 57      Date
#> 58   integer
#> 59 character
#> 60 character
#> 61      Date
#> 62      Date
field_dict[field_dict$type == "Date", ]
#>                                      api_path                col_name type
#> 5                              stiftelsesdato           founding_date Date
#> 6           registreringsdatoEnhetsregisteret       registration_date Date
#> 43                                konkursdato         bankruptcy_date Date
#> 45                         underAvviklingDato        liquidation_date Date
#> 48 registreringsdatoMerverdiavgiftsregisteret   vat_registration_date Date
#> 50        registreringsdatoForetaksregisteret  business_register_date Date
#> 52   registreringsdatoFrivillighetsregisteret nonprofit_register_date Date
#> 57                               vedtektsdato           articles_date Date
#> 61                                 slettedato           deletion_date Date
#> 62                             datoEierskifte   ownership_change_date Date
```
