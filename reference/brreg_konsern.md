# Retrieve the corporate group structure (konsernstruktur)

Fetch the registered group hierarchy for a Norwegian legal entity from
the Enhetsregisteret konsernstruktur endpoint (added by BRREG
2026-06-24). The tree is returned flat: one row per node, root included
at `level = 0`, each child carrying its link form (`knytningsform`, e.g.
`KDAT` "Konsern datter"), ownership basis (`grunnlag`, e.g. `"100%"`),
and the registration date of the relation.

## Usage

``` r
brreg_konsern(org_nr)
```

## Arguments

- org_nr:

  Character. A single 9-digit organization number.

## Value

A tibble with one row per node in the group tree. Columns: `org_nr` (the
queried entity), `node_org_nr`, `node_name`, `level` (0 for the root),
`link_form`, `link_form_desc`, `basis`, `relation_date` (Date),
`parent_org_nr`, `parent_name`, `legal_form`, `legal_form_desc`. A
zero-row tibble with the same typed columns if no group structure is
registered.

## Details

The JSON response omits `knytningsform` on the root node while the API's
CSV variant emits it as `KKKK` "Øverste mor"; the root row is
synthesized here to match the CSV semantics.

This is the ownership hierarchy and is distinct from
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
which searches `overordnetEnhet` — the administrative parent relation
used in public-sector (ORGL) structures, not konsern ownership.

## 404 semantics

The endpoint returns 404 both for organization numbers that do not exist
and for live entities that are not part of any registered group — the
common case for ordinary companies. The `in_corporate_group` column from
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
disambiguates the two without a second lookup here.

## Status handling

The per-entity endpoints behind
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
`brreg_konsern()`,
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

[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md)
for the ORGL administrative hierarchy,
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for the `in_corporate_group` flag,
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md)
for roles an entity holds in others.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
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
brreg_konsern("923609016") # Equinor ASA
}
```
