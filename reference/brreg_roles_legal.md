# Retrieve roles an entity holds in other entities

Reverse role lookup: find all entities where the given entity holds a
role (e.g. parent company, shareholder, general partner). This is
distinct from
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
which returns who holds roles IN the given entity.

## Usage

``` r
brreg_roles_legal(org_nr)
```

## Arguments

- org_nr:

  Character. A single 9-digit organization number.

## Value

A tibble with one row per role held. Columns: `org_nr` (queried entity),
`target_org_nr` (entity where role is held), `target_name`, `role_code`,
`role`, `share` (ownership share if applicable), `deregistered`. A
`resigned` column is present only when the payload carries the
`fratraadt` field, removed by BRREG on 2026-06-16. An entity holding no
roles elsewhere yields a zero-row tibble with the same typed columns.

## Status handling

The per-entity endpoints behind
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
`brreg_roles_legal()`,
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

[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
for who holds roles in an entity.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_roles_legal("923609016")  # Equinor's roles in other entities
}
```
