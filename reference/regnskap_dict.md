# Regnskap field dictionary: filing JSON paths to English column names

A tibble mapping dot paths of the Regnskapsregisteret filing JSON to
English column names and R types, with the columns of
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md)
applies it exactly as
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
applies
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md):
leaves outside the three statement objects become the filing's scalar
columns, leaves inside them become the `item` codes of the nested
`items` table, and paths absent from the dictionary pass through with
auto-generated snake_case names. Source spellings such as
`regnkapsprinsipper` and `sumInnskuttEgenkaptial` are the API's own.

## Usage

``` r
regnskap_dict
```

## Format

A tibble with 46 rows and 3 columns:

- api_path:

  Dot-notation path in the filing JSON (e.g.
  `"regnskapsperiode.tilDato"`, `"eiendeler.sumEiendeler"`).

- col_name:

  English name used in package output: a column of the filing row or an
  `item` code (e.g. `"period_end"`, `"total_assets"`).

- type:

  R type for coercion: `"character"`, `"Date"`, `"integer"`,
  `"numeric"`, or `"logical"`.

## Source

Package-authored; see
[tidybrreg_provenance](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md).

## See also

[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md),
[regnskap_items](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md).

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`regnskap_groups`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md),
[`regnskap_items`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md),
[`tidybrreg_provenance`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md)

## Examples

``` r
regnskap_dict
#> # A tibble: 46 × 3
#>    api_path                       col_name             type     
#>    <chr>                          <chr>                <chr>    
#>  1 id                             filing_id            integer  
#>  2 journalnr                      journal_nr           character
#>  3 regnskapstype                  account_type         character
#>  4 virksomhet.organisasjonsnummer org_nr               character
#>  5 virksomhet.organisasjonsform   legal_form           character
#>  6 virksomhet.morselskap          parent_company       logical  
#>  7 regnskapsperiode.fraDato       period_start         Date     
#>  8 regnskapsperiode.tilDato       period_end           Date     
#>  9 valuta                         currency             character
#> 10 avviklingsregnskap             liquidation_accounts logical  
#> # ℹ 36 more rows
regnskap_dict[regnskap_dict$type == "numeric", ]
#> # A tibble: 31 × 3
#>    api_path                                                       col_name type 
#>    <chr>                                                          <chr>    <chr>
#>  1 egenkapitalGjeld.sumEgenkapitalGjeld                           total_e… nume…
#>  2 egenkapitalGjeld.egenkapital.sumEgenkapital                    total_e… nume…
#>  3 egenkapitalGjeld.egenkapital.innskuttEgenkapital.sumInnskuttE… paid_in… nume…
#>  4 egenkapitalGjeld.egenkapital.opptjentEgenkapital.sumOpptjentE… retaine… nume…
#>  5 egenkapitalGjeld.gjeldOversikt.sumGjeld                        total_l… nume…
#>  6 egenkapitalGjeld.gjeldOversikt.kortsiktigGjeld.sumKortsiktigG… current… nume…
#>  7 egenkapitalGjeld.gjeldOversikt.langsiktigGjeld.sumLangsiktigG… long_te… nume…
#>  8 eiendeler.sumEiendeler                                         total_a… nume…
#>  9 eiendeler.omloepsmidler.sumOmloepsmidler                       current… nume…
#> 10 eiendeler.anleggsmidler.sumAnleggsmidler                       fixed_a… nume…
#> # ℹ 21 more rows
```
