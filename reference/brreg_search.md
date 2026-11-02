# Search Norwegian legal entities

Query the Central Coordinating Register by name, legal form, industry,
geography, and other criteria. Results are paginated automatically up to
`max_results`.

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

  Integer. Employee count range. For privacy the register refuses a
  range that lies within one to four employees (HTTP 400,
  `tidybrreg_error_http` with the register's message); ranges starting
  at 0 or at 5 and above are served.

- bankrupt:

  Logical. If `TRUE`, return only bankrupt entities. Only supported for
  `registry = "enheter"`; supplying it for `"underenheter"` is an error.

- parent_org_nr:

  Character. Filter to subsidiaries of this org.

- max_results:

  Integer. Maximum entities to return (default 200). Values above the
  10,000 result window are allowed but abort when the register reports
  more matches than the window can deliver.

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
([field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md));
only observed fields are emitted (see
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)).
Attributes: `total_matches`, the number of matches the register
reported, and `complete`, `FALSE` when fewer rows were returned than
matched. A valid empty result is a zero-row tibble with character
columns `org_nr`, `name` and `legal_form`.

## Norwegian legal forms

Common codes for the `legal_form` parameter:

- **AS**: Private limited company (like UK Ltd, German GmbH)

- **ASA**: Public limited company (like UK PLC, German AG)

- **ENK**: Sole proprietorship

- **NUF**: Norwegian-registered foreign entity (branch office)

See
[legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md)
for the complete list with English translations.

## Result window

The search endpoints allow a page size of up to 10,000 but reject any
page where `size * (page + 1)` exceeds 10,000 (observed 2026-08-08: a
Bergen municipality query reported 57,954 matches; result 10,001
answered HTTP 400 `size * (page+1) kan ikke overstige 10_000`). A query
matching more entities than that window cannot be retrieved completely
through search. When the register reports more matches than the window
and `max_results` asks for more than the window, the call aborts with a
`tidybrreg_error_result_window` before any page is returned; narrow the
query (for example by `municipality_code`, `legal_form` or `nace_code`),
or use
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
for the full register. When `max_results` is at or below the window the
first `max_results` matches are returned and the result carries
`complete = FALSE` plus a `tidybrreg_warning_truncated` whenever more
matches exist.

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

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for single lookups,
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
for translating codes to English,
[tidybrreg_conditions](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md)
for the errors and warnings signalled.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md),
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
