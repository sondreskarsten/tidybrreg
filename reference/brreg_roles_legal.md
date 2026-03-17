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

  Character. 9-digit organization number.

## Value

A tibble with one row per role held. Columns: `org_nr` (queried entity),
`target_org_nr` (entity where role is held), `target_name`, `role_code`,
`role`, `share` (ownership share if applicable), `resigned`,
`deregistered`.

## See also

[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
for who holds roles in an entity.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_roles_legal("923609016")  # Equinor's roles in other entities
}
```
