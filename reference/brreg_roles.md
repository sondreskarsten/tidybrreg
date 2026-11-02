# Retrieve board members, officers, and auditors

Fetch all registered roles for a Norwegian legal entity. Returns one row
per role assignment. Person-held roles include name and birth date.
Entity-held roles (auditor firms, accountants) include the entity's
organization number.

## Usage

``` r
brreg_roles(org_nr)
```

## Arguments

- org_nr:

  Character. A single 9-digit organization number, validated with
  [`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md).

## Value

A tibble with one row per role assignment. Columns: `org_nr`,
`role_group_code`, `role_group`, `role_code`, `role`, `first_name`,
`middle_name`, `last_name`, `birth_date` (Date), `deceased`,
`entity_org_nr`, `entity_name`, `deregistered`, `ordering`,
`elected_by`, `group_modified` (Date), `person_id`. A `resigned` column
is present only when the payload carries the `fratraadt` field, which
BRREG removed on 2026-06-16; live responses no longer include the
column, while replays of older data retain it. An entity with no
registered roles yields a zero-row tibble with the same typed columns.

## Details

Role types and groups are returned as English labels looked up from the
package's
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
and
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
reference datasets. Original Norwegian codes are preserved in
`role_code` and `role_group_code`.

## Person identification

The `person_id` column is a synthetic key composed of birth date, last
name, first name, and middle name. It enables network analysis across
companies but has a non-trivial collision risk for common Norwegian
names sharing a birth date. The brreg public API does not expose
national identity numbers.

## Status handling

The per-entity endpoints behind `brreg_roles()`,
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md)
and
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md)
share one contract. HTTP 404 means the organization number is unknown to
that endpoint, which for konsern, signatur, prokura and regnskap is the
ordinary case of an entity with nothing registered there: the typed
zero-row tibble is returned with attribute `http_status = 404L` and no
warning. HTTP 410 means the entity has been deleted: the typed zero-row
tibble is returned with `http_status = 410L`, `deletion_date`, and a
`tidybrreg_warning_deleted`. Any other status of 400 or above aborts
with a `tidybrreg_error_http`. A successful response with nothing
registered returns the typed zero-row tibble with no attribute. Use
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
to distinguish a non-existent organization number from a live entity
with nothing registered.

## See also

[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
and
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
for the English lookup tables,
[tidybrreg_conditions](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md)
for the conditions signalled.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_roles("923609016")  # Equinor ASA
}
```
