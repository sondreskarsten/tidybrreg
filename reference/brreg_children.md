# Get child entities in the organisational hierarchy

Query the enheter registry for entities whose `overordnetEnhet` matches
the given org number. This traverses the ORGL parent-child hierarchy
(e.g. Stortinget to Riksrevisjonen), which is distinct from the
enhet-to-underenhet relationship.

## Usage

``` r
brreg_children(org_nr, max_results = 200, type = c("code", "label"))
```

## Arguments

- org_nr:

  Character. 9-digit organization number of the parent entity
  (hovedenhet).

- max_results:

  Integer. Maximum sub-units to return (default 200).

- type:

  One of `"code"` (default) or `"label"`.

## Value

A tibble with one row per child entity. Same column schema as
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
with `registry = "enheter"`.

## See also

[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md)
for sub-units (BEDR/AAFY),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for single lookups.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_children("971524960")
}
```
