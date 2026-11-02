# Regnskap groups: the objects that group line items, with labels

One row per object of the filing JSON that contains line items, from the
three statements (`eiendeler`, `egenkapitalGjeld`,
`resultatregnskapResultat`, level 0) down to the leaf groups. The `code`
is the `group` (and, for level-0 rows, the `statement`) of the `items`
table of
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md);
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
translates it to `name_en` or `name_no`, as
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
does for role groups.

## Usage

``` r
regnskap_groups
```

## Format

A tibble with 17 rows and 4 columns:

- path:

  Dot-notation path of the object in the filing JSON.

- code:

  Group code used in package output (e.g. `"assets"`,
  `"current_liabilities"`).

- name_en:

  English name.

- name_no:

  Norwegian name, the presentation-plan caption.

## Source

Package-authored; see
[tidybrreg_provenance](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md).

## See also

[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[regnskap_dict](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md),
[regnskap_items](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md).

Other tidybrreg reference data:
[`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[`regnskap_dict`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md),
[`regnskap_items`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md),
[`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md),
[`tidybrreg_provenance`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md)

## Examples

``` r
regnskap_groups
#> # A tibble: 17 × 4
#>    path                                                    code  name_en name_no
#>    <chr>                                                   <chr> <chr>   <chr>  
#>  1 eiendeler                                               asse… Assets  Eiende…
#>  2 eiendeler.omloepsmidler                                 curr… Curren… Omløps…
#>  3 eiendeler.anleggsmidler                                 fixe… Fixed … Anlegg…
#>  4 egenkapitalGjeld                                        equi… Equity… Egenka…
#>  5 egenkapitalGjeld.egenkapital                            equi… Equity  Egenka…
#>  6 egenkapitalGjeld.egenkapital.innskuttEgenkapital        paid… Paid-i… Innsku…
#>  7 egenkapitalGjeld.egenkapital.opptjentEgenkapital        reta… Retain… Opptje…
#>  8 egenkapitalGjeld.gjeldOversikt                          liab… Liabil… Gjeld  
#>  9 egenkapitalGjeld.gjeldOversikt.kortsiktigGjeld          curr… Curren… Kortsi…
#> 10 egenkapitalGjeld.gjeldOversikt.langsiktigGjeld          long… Long-t… Langsi…
#> 11 resultatregnskapResultat                                inco… Income… Result…
#> 12 resultatregnskapResultat.driftsresultat                 oper… Operat… Drifts…
#> 13 resultatregnskapResultat.driftsresultat.driftsinntekter oper… Operat… Drifts…
#> 14 resultatregnskapResultat.driftsresultat.driftskostnad   oper… Operat… Drifts…
#> 15 resultatregnskapResultat.finansresultat                 fina… Financ… Finans…
#> 16 resultatregnskapResultat.finansresultat.finansinntekt   fina… Financ… Finans…
#> 17 resultatregnskapResultat.finansresultat.finanskostnad   fina… Financ… Finans…
brreg_label(c("assets", "operating"), dic = "regnskap_group", lang = "no")
#> [1] "Eiendeler"      "Driftsresultat"
```
