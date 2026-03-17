# Build a director interlock network

Construct a bipartite graph of entities and persons linked by
board/officer roles. Returns a `tbl_graph` (tidygraph) object suitable
for centrality analysis and ggraph visualization.

## Usage

``` r
brreg_board_network(org_nrs = NULL, roles_data = NULL)
```

## Arguments

- org_nrs:

  Character vector of organization numbers to include. Roles are fetched
  via
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
  for each entity.

- roles_data:

  Optional pre-fetched roles tibble (from
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)).
  If provided, `org_nrs` is ignored.

## Value

A `tbl_graph` with two node types: `"entity"` (identified by `org_nr`)
and `"person"` (identified by `person_id`). Edge attributes include
`role_code`, `role_group_code`, and `org_nr`.

## Details

For a full ego network including sub-units, child entities, and legal
roles in addition to board roles, use
[`brreg_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_network.md)
instead.

## See also

[`brreg_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_network.md)
for full entity network graphs,
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
to fetch role data,
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md)
for board-level covariates.

Other tidybrreg governance functions:
[`brreg_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_network.md),
[`brreg_survival_data()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_survival_data.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet() && requireNamespace("tidygraph", quietly = TRUE)
# \donttest{
net <- brreg_board_network(c("923609016", "984851006"))
net
# }
}
```
