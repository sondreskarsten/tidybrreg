# Build an entity network graph

Construct a `tbl_graph` (tidygraph) representing the relationships
around one or more seed entities. At depth 1, the graph includes
sub-units, child entities, role holders, and legal role targets — all
reachable via direct API calls. At depth 2, the graph expands through
person nodes to discover board interlocks, requiring local bulk data
(see Details).

## Usage

``` r
brreg_network(
  org_nr,
  depth = 1L,
  include = c("underenheter", "children", "roles", "legal_roles"),
  download = FALSE
)
```

## Arguments

- org_nr:

  Character vector of seed organization numbers.

- depth:

  Integer. 0 = seed only, 1 = ego network (default), 2 = expand through
  persons (requires bulk data).

- include:

  Character vector of relationship types to include. Default includes
  all available types. Current types: `"underenheter"`, `"children"`,
  `"roles"`, `"legal_roles"`.

- download:

  Logical. If `TRUE` and depth \> 1, offer to download missing bulk data
  interactively. Default `FALSE`.

## Value

A `tbl_graph` with node attributes `node_id`, `node_type`, `name`,
`org_nr`, `person_id`, and edge attributes `from`, `to`, `edge_type`,
`role_code`, `role`.

## Depth and data requirements

- **Depth 0**: Seed entity only. 1 API call per seed.

- **Depth 1**: Full ego network. 5-7 API calls per seed.

- **Depth 2**: Board interlocks via person-to-entity reverse lookup.
  Requires local bulk data for enheter, underenheter, and roller. Run
  [`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
  for each type first, or call with `download = TRUE` to trigger
  downloads interactively.

## Extensibility

The `include` parameter controls which relationship types are traversed.
Each type maps to an internal collector function. Future versions may
add types such as `"addresses"`, `"prior_owners"`, or `"accounting"`.

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for single lookups,
[`brreg_board_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_network.md)
for the roles-only subgraph,
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md)
to check bulk data availability.

Other tidybrreg governance functions:
[`brreg_board_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_network.md),
[`brreg_survival_data()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_survival_data.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet() && requireNamespace("tidygraph", quietly = TRUE)
# \donttest{
net <- brreg_network("923609016")
net

tidygraph::as_tibble(net, "nodes")
tidygraph::as_tibble(net, "edges")
# }
}
```
