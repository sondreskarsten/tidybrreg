# Corporate governance research

tidybrreg provides tools for corporate governance research using
Norwegian business registry data. This vignette covers director
interlock networks, board composition analysis, reverse role lookups,
and firm survival data preparation.

## Board composition

Retrieve all registered roles for an entity and derive board-level
covariates:

``` r
library(tidybrreg)

roles <- brreg_roles("923609016")  # Equinor ASA

# Board summary: size, composition, officer indicators
brreg_board_summary(roles)
#> # A tibble: 1 × 10
#>   org_nr    board_size n_chair n_deputy_chair n_members n_alternates
#>   <chr>          <int>   <int>          <int>     <int>        <int>
#> 1 923609016         10       1              1         8            0
#>   n_observers has_ceo has_auditor auditor_org_nr
#>         <int> <lgl>   <lgl>      <chr>
#>             0 TRUE    TRUE       980573984
```

The role data includes person names, birth dates (not national identity
numbers), role codes, and whether the person has resigned. Entity-held
roles (auditor firms, accountants) include the entity’s organization
number.

### Person identification

The `person_id` column is a synthetic key composed of birth date + last
name + first name. This enables network analysis across companies but
has a non-trivial collision risk for common Norwegian names sharing a
birth date. The brreg public API does not expose national identity
numbers. The authenticated API (`/autorisert-api/`) provides
fødselsnummer via Maskinporten, but tidybrreg does not support
authenticated endpoints.

## Reverse role lookup

[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md)
answers the reverse question: what roles does entity X hold in OTHER
entities?

``` r
# Equinor's ownership and board roles in other entities
holdings <- brreg_roles_legal("923609016")
holdings
#> # A tibble: 70 × 8
#>   org_nr    target_org_nr target_name                   role       share
#>   <chr>     <chr>         <chr>                         <chr>      <chr>
#> 1 923609016 819334552     TECHNOLOGY CENTRE MONGSTAD DA Partner... 22%
#> 2 923609016 925461784     EQUINOR DEZASSETE AS          Accountant NA
```

This is useful for mapping corporate group structures, identifying
holding company relationships, and tracing ownership chains.

## Director interlock networks

Build a bipartite graph of entities and persons linked by board roles:

``` r
# Select a set of entities (e.g., top energy companies)
org_nrs <- c("923609016", "984851006", "985224323", "990888213")

# Build the network (requires tidygraph)
net <- brreg_board_network(org_nrs)
net
#> # A tbl_graph: 85 nodes and 92 edges
#> # An undirected multigraph with 4 components
#> # Node Data: 85 × 2 (active)
#>   name      node_type
#>   <chr>     <chr>
#> 1 923609016 entity
#> 2 984851006 entity
```

The `tbl_graph` object is compatible with the tidygraph/ggraph ecosystem
for centrality analysis and visualization:

``` r
library(tidygraph)
library(ggraph)

net |>
  activate(nodes) |>
  mutate(degree = centrality_degree()) |>
  ggraph(layout = "fr") +
  geom_edge_link(alpha = 0.3) +
  geom_node_point(aes(size = degree, colour = node_type)) +
  theme_graph()
```

### Pre-fetched role data

For large networks, pre-fetch roles and pass them directly:

``` r
all_roles <- brreg_download(type = "roller")
net <- brreg_board_network(roles_data = all_roles)
```

## Firm survival analysis

Prepare time-to-event data compatible with
[`survival::Surv()`](https://rdrr.io/pkg/survival/man/Surv.html):

``` r
# Download or search for a population of firms
firms <- brreg_search(legal_form = "AS", municipality_code = "0301",
                       max_results = 5000)

# Add survival variables
surv <- brreg_survival_data(firms)
surv[, c("org_nr", "entry_date", "exit_date", "duration_years", "event")]
#> # A tibble: 5,000 × 5
#>   org_nr    entry_date exit_date  duration_years event
#>   <chr>     <date>     <date>              <dbl> <int>
#> 1 810034882 2010-01-15 NA                  15.2      0
#> 2 912345678 2015-06-01 2023-11-30           8.5      1
```

The function applies the following conventions:

- **Entry**: `founding_date` (stiftelsesdato) by default. Override with
  `entry_var = "registration_date"` for registration-based entry.
- **Exit**: First non-NA among `bankruptcy_date` \> `liquidation_date`
  \> `forced_dissolution_date` \> `deletion_date` (hierarchy applied in
  order).
- **Censoring**: Firms alive at `censoring_date` (default: today)
  receive `event = 0`. Firms with an exit date receive `event = 1`.
- **Duration**: `duration_years` = (exit or censoring date - entry date)
  / 365.25.

Use with the survival package:

``` r
library(survival)
km <- survfit(Surv(duration_years, event) ~ legal_form, data = surv)
plot(km)
```

## Bulk role snapshots for panel analysis

The roller totalbestand endpoint provides all roles for all entities in
a single download. Save dated snapshots for historical comparison:

``` r
# Save today's complete role data
brreg_snapshot("roller")

# Build a role panel over time
brreg_snapshots("roller")
```

Combine with entity snapshots for board composition panels:

``` r
# Annual entity panel
entity_panel <- brreg_panel("year", cols = c("legal_form", "employees"))

# Join with role counts from roller snapshots
# (requires manual aggregation from role data)
```
