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

  Character. 9-digit organization number.

## Value

A tibble with one row per role assignment. Columns: `org_nr`,
`role_group`, `role_group_code`, `role`, `role_code`, `first_name`,
`middle_name`, `last_name`, `birth_date`, `deceased`, `entity_org_nr`,
`entity_name`, `resigned`, `person_id`. Returns an empty tibble if the
entity has no registered roles.

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

## See also

[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md)
for derived board covariates,
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
and
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
for the English lookup tables.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_roles("923609016")  # Equinor ASA
}
```
