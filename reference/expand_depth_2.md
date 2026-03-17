# Expand network through person nodes using local bulk data

Lazy pipeline: resolves roller first, filters to seed persons,
early-exits if no new orgs discovered, then resolves
enheter/underenheter only for the org_nrs actually needed. With arrow +
parquet snapshots, only matching row groups are read from disk at each
step.

## Usage

``` r
expand_depth_2(nodes, edges, seed_orgs, download = FALSE)
```
