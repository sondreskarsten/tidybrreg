# Get all sub-units (underenheter) belonging to an entity

Convenience wrapper around
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
that queries the underenheter registry filtered by `overordnetEnhet`.
Each Norwegian legal entity that operates a business has one or more
sub-units (BEDR/AAFY) representing physical locations or activities.

## Usage

``` r
brreg_underenheter(org_nr, max_results = 200, type = c("code", "label"))
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

A tibble with one row per sub-unit. Same column schema as
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
with `registry = "underenheter"`.

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for the parent entity,
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md)
for child enheter in the ORGL hierarchy.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_underenheter("923609016")
}
```
