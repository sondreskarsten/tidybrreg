# Look up a Norwegian legal entity

Retrieve registration details for a legal entity from Norway's Central
Coordinating Register for Legal Entities (Enhetsregisteret), maintained
by the Brønnøysund Register Centre. Every legal entity operating in
Norway is assigned a unique 9-digit organization number and registered
in this central register.

## Usage

``` r
brreg_entity(
  org_nr,
  registry = c("enheter", "underenheter"),
  type = c("code", "label")
)
```

## Arguments

- org_nr:

  Character. A 9-digit Norwegian organization number. Validated using
  [`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md)
  before the API call.

- registry:

  One of `"enheter"` (main entities, default) or `"underenheter"`
  (sub-entities / establishments). Sub-entities have different fields
  (e.g. `overordnetEnhet` for the parent entity, `beliggenhetsadresse`
  instead of `forretningsadresse`).

- type:

  A type of variables: `"code"` (default) returns raw codes, `"label"`
  returns English labels for coded columns (legal form, NACE, sector,
  etc.), following the eurostat package's pattern.

## Value

A tibble with one row and one column per API field. Column names follow
the package field dictionary. Key columns include `org_nr`, `name`,
`legal_form`, `employees`, `founding_date`, `nace_1`,
`municipality_code`, `bankrupt`, and `parent_org_nr`. For deleted
entities (HTTP 410), returns a tibble with columns `org_nr`, `deleted`,
and `deletion_date`.

## Details

Column names are translated from Norwegian to English via the package
field dictionary
([field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)).
API fields not in the dictionary pass through with auto-generated
snake_case names, so new fields added by brreg are never silently
dropped. Use
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
to translate coded values (legal forms, NACE codes) to English
descriptions.

## See also

[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
for querying multiple entities,
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
for translating codes to English,
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
for the column name mapping.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# Equinor ASA — Norway's largest company
brreg_entity("923609016")

# With English labels (eurostat pattern)
brreg_entity("923609016", type = "label")

# Or pipe to brreg_label() for more control
brreg_entity("923609016") |> brreg_label(code = "legal_form")
}
```
