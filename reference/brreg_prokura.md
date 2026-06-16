# Retrieve procuration authority (prokura)

Fetch the registered procuration combinations for a Norwegian legal
entity from the Brønnøysund Fullmakt service. Procuration is a
commercial power of attorney under the Norwegian Powers of Attorney Act
(prokuraloven): a holder may bind the entity in ordinary business, but
not, absent separate authority, sell or encumber its real property. It
is a narrower and separate mandate from the general signing authority
returned by
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md).

## Usage

``` r
brreg_prokura(org_nr)
```

## Arguments

- org_nr:

  Character. 9-digit organization number.

## Value

A tibble with the same columns as
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
with `signature_type` set to `"prokura"`. Returns an empty tibble if no
procuration is registered.

## Details

One row is returned per person within each registered combination.

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

## See also

[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md)
for general signing authority.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
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
brreg_prokura("923609016") # Equinor ASA
}
```
