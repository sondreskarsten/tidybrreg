# Search Norwegian legal entities

Query the Central Coordinating Register by name, legal form, industry,
geography, and other criteria. Results are paginated automatically up to
`max_results` or the API's 10,000-result ceiling, whichever is lower.

## Usage

``` r
brreg_search(
  name = NULL,
  legal_form = NULL,
  municipality_code = NULL,
  nace_code = NULL,
  min_employees = NULL,
  max_employees = NULL,
  bankrupt = NULL,
  parent_org_nr = NULL,
  max_results = 200,
  registry = c("enheter", "underenheter"),
  type = c("code", "label")
)
```

## Arguments

- name:

  Character. Entity name (partial match, case-insensitive).

- legal_form:

  Character. Legal form code: `"AS"`, `"ASA"`, `"ENK"`, etc. See
  [legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md)
  for valid codes.

- municipality_code:

  Character. 4-digit Norwegian municipality code.

- nace_code:

  Character. NACE industry code (e.g. `"64.190"`).

- min_employees, max_employees:

  Integer. Employee count range.

- bankrupt:

  Logical. If `TRUE`, return only bankrupt entities.

- parent_org_nr:

  Character. Filter to subsidiaries of this org.

- max_results:

  Integer. Maximum entities to return (default 200). The API caps search
  results at 10,000; use
  [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
  for larger extractions.

- registry:

  One of `"enheter"` (main entities, default) or `"underenheter"`
  (sub-entities / establishments). Sub-entities use
  `beliggenhetsadresse.kommunenummer` instead of `kommunenummer` for
  geographic filtering, and the `bankrupt` parameter is not available.

- type:

  A type of variables: `"code"` (default) returns raw codes, `"label"`
  returns English labels for coded columns.

## Value

A tibble with one row per entity. Column names follow the package field
dictionary
([field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)).
An attribute `total_matches` records the total number of matches in the
registry.

## Norwegian legal forms

Common codes for the `legal_form` parameter:

- **AS**: Private limited company (like UK Ltd, German GmbH)

- **ASA**: Public limited company (like UK PLC, German AG)

- **ENK**: Sole proprietorship

- **NUF**: Norwegian-registered foreign entity (branch office)

See
[legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md)
for the complete list with English translations.

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for single lookups,
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
for translating codes to English.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# Search by name
brreg_search(name = "Equinor")

# Large private companies in Oslo
brreg_search(legal_form = "AS", municipality_code = "0301",
             min_employees = 500, max_results = 10)
}
```
