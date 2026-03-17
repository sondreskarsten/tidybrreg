# Derive board-level summary covariates from role data

Compute firm-level variables commonly used in corporate governance
research: board size, composition counts, and officer indicators.

## Usage

``` r
brreg_board_summary(roles)
```

## Arguments

- roles:

  A tibble returned by
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md).

## Value

A 1-row tibble with columns: `org_nr`, `board_size`, `n_chair`,
`n_deputy_chair`, `n_members`, `n_alternates`, `n_observers`, `has_ceo`,
`has_auditor`, `auditor_org_nr`.

## See also

[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
for the underlying role data.

Other tidybrreg entity functions:
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_roles("923609016") |> brreg_board_summary()
}
```
