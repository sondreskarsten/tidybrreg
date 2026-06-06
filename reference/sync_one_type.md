# Sync one CDC stream

Sync one CDC stream

## Usage

``` r
sync_one_type(
  type,
  cursor,
  size = 10000L,
  roller_method = "bulk",
  verbose = TRUE
)
```

## Arguments

- roller_method:

  Passed from
  [`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md).
  Controls roller sync strategy: `"bulk"` (totalbestand diff) or `"cdc"`
  (per-org).
