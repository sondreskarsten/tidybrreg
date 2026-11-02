# Typed zero-row tibble for entity results

The columns an empty search or lookup result carries. Entity emission is
batch-scoped, so an empty batch has observed nothing; the identifying
columns are still present, typed, so downstream code can select them.

## Usage

``` r
empty_entities()
```
