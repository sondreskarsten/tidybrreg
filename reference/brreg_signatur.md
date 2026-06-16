# Retrieve signature authority (signaturrett)

Fetch the registered signing combinations for a Norwegian legal entity
from the Brønnøysund Fullmakt service. Signature authority determines
who may bind the entity in general, and is distinct from the roles
returned by
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md):
an entity may have many board members yet a signing rule such as "the
board jointly" or "the general manager alone".

## Usage

``` r
brreg_signatur(org_nr)
```

## Arguments

- org_nr:

  Character. 9-digit organization number.

## Value

A tibble with one row per person per signing combination. Columns:
`org_nr`, `entity_name`, `signature_type`, `rule_status`, `rule_text`,
`combination_id`, `combination_code`, `rule`, `name`, `birth_date`,
`role_code`, `role`. Returns an empty tibble if the entity has no
registered signing combination.

## Details

Each registered combination (`combination_id`) carries a rule (`rule`,
e.g. "Styret i fellesskap") and the persons who satisfy it. One row is
returned per person within each combination.

## Person identification

The Fullmakt service returns each person's name as a single string in
`name`; it does not split it into given and family names, so no
synthetic `person_id` is constructed. Join to
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
on `birth_date` together with `name` at query time if cross-referencing
to the role network is required. `role_code` carries the registry's role
code (joinable to
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md));
`role` is the registry's own Norwegian description.

## Standardised vs registered rule

`rule` and `combination_code` come from the registry's structured
combination. Where the rule has been standardised (`rule_status` code
`"RF"`) this is the registered rule. Where it has not (`"RI"`), the
structured combination is the statutory default ("the board jointly")
and the actually registered rule is the free text in `rule_text`; read
`rule_text` in that case. `rule_text` may be `NA` when no free text is
recorded.

## See also

[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md)
for procuration,
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
for the underlying role assignments.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_signatur("923609016") # Equinor ASA
}
```
