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
  registry = c("auto", "enheter", "underenheter"),
  type = c("code", "label")
)
```

## Arguments

- org_nr:

  Character. A single 9-digit Norwegian organization number. Validated
  using
  [`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md)
  before the API call; a vector of several numbers is an error (iterate
  with [`lapply()`](https://rdrr.io/r/base/lapply.html)).

- registry:

  One of `"auto"` (default, tries enheter then underenheter),
  `"enheter"` (main entities only), or `"underenheter"` (sub-entities
  only). Sub-entities have different fields (e.g. `overordnetEnhet` for
  the parent entity, `beliggenhetsadresse` instead of
  `forretningsadresse`).

- type:

  A type of variables: `"code"` (default) returns raw codes, `"label"`
  returns English labels for coded columns (legal form, NACE, sector,
  etc.), following the eurostat package's pattern. Labelling NACE and
  sector codes consults SSB KLASS on first use in a session; see
  [`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md).

## Value

A tibble with one row and one column per field the API returned, named
via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
plus `registry` (which registry answered) and `deleted` (logical).
Frequently present columns include `org_nr`, `name`, `legal_form`,
`employees`, `founding_date`, `nace_1`, `municipality_code`, `bankrupt`,
and `parent_org_nr`; `historiske_navn` and `annotations` are
list-columns of tibbles (see the section on tidy shape).

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

## Observed fields only

The register emits only the fields that apply to an entity: a sole
proprietorship (`ENK`) typically carries no `founding_date` or
`employees`, a foreign branch (`NUF`) no `municipality_code`. The
returned columns are exactly the fields the response carried, so every
column other than `org_nr`, `registry` and `deleted` is conditionally
present. Test for a column with `"x" %in% names(result)` rather than
assuming it.

## Tidy shape

Every tibble the package returns is tidy in Wickham's sense: one
observation per row, one variable per column, one observational unit per
table. The register nests two kinds of array inside an entity. Arrays of
strings (`business_address`, `postal_address`, `location_address`,
`purpose`, `activity`) are the line fragments of one value and are
joined with `"\n"`, which no fragment contains, so `strsplit(x, "\n")`
recovers the lines. Arrays of objects (`historiske_navn`, `annotations`,
any array of objects the register adds) are observations of another unit
and are nested as a list-column of tibbles, one row per element with
snake_case columns, `NULL` for an entity without them;
[`tidyr::unnest()`](https://tidyr.tidyverse.org/reference/unnest.html)
expands them to their own table. An empty array is not an observation
and emits no column. Nothing is serialized to JSON text.

## Deleted entities

BRREG reports a deleted entity either as HTTP 410 or, for most
deletions, as HTTP 200 with `respons_klasse = "SlettetEnhet"` and a
`slettedato`. Both are modelled the same way: `deleted` is `TRUE`,
`deletion_date` is the parsed date, every other field the response
carried is kept, and a `tidybrreg_warning_deleted` is signalled (silence
it with `suppressWarnings(classes = "tidybrreg_warning_deleted")`). Live
entities carry `deleted = FALSE`.

## See also

[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
for querying multiple entities,
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
for translating codes to English,
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
for the column name mapping,
[tidybrreg_conditions](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md)
for the errors and warnings signalled.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md),
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
