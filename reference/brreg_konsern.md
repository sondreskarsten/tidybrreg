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

  Character. 9-digit organization number.

## Value

A tibble with one row per node in the group tree. Columns: `org_nr` (the
queried entity), `node_org_nr`, `node_name`, `level` (0 for the root),
`link_form`, `link_form_desc`, `basis`, `relation_date` (Date),
`parent_org_nr`, `parent_name`, `legal_form`, `legal_form_desc`. Returns
an empty tibble if no group structure is registered.

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
common case for ordinary companies. A warning is issued and an empty
tibble returned; the `in_corporate_group` column from
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
disambiguates the two without a second lookup here.

## See also

[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md)
for the ORGL administrative hierarchy,
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for the `in_corporate_group` flag,
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md)
for roles an entity holds in others.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
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
