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

  Character. A single 9-digit organization number.

## Value

A tibble with the same columns as
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
with `signature_type` set to `"procuration"`. A zero-row tibble with the
same typed columns if no procuration is registered.

## Details

One row is returned per person within each registered combination.

## Person identification

The Fullmakt service returns each person's name as a single string in
`name`; it does not split it into given and family names, so no
synthetic `person_id` is constructed. Join to
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
on `birth_date` together with `name` at query time if cross-referencing
to the role network is required. Role designations are returned as
English labels looked up from
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md),
with the original Norwegian code preserved in `role_code`; the
signing-mode designations (`SIGN`, `SIFE`, `SIHV`, `PROK`, `POFE`,
`POHV`) are included in
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
alongside the board roles. Birth dates arrive as `DD.MM.YYYY` from this
service and as ISO dates from the roles endpoint; both are parsed to
`Date`, so the two join directly.

## Rules the service declines to resolve

For some entities (Equinor ASA among them) the service answers HTTP 200
with no combinations and a routine status instead: code `NA`, "Generelle
unntak, finnes roller som har status det ikke kan foretas maskinelt
oppslag mot", meaning a rule is registered but cannot be resolved
mechanically. The typed zero-row tibble is then returned with attributes
`http_status = 200L`, `routine_status` and `routine_text`, and a
`tidybrreg_warning_unresolved` is signalled, so the case is
distinguishable from an entity with nothing registered (no attribute, no
warning).

## Status handling

The per-entity endpoints behind
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
`brreg_prokura()` and
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

[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md)
for general signing authority.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
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
brreg_prokura("923609016") # Equinor ASA
}
```
