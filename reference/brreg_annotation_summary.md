# Count entities with active annotations

Quick summary of how many entities currently carry påtegninger, grouped
by annotation type.

## Usage

``` r
brreg_annotation_summary()
```

## Value

A tibble with `infotype` and `n`.

## See also

Other tidybrreg data management functions:
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md)

## Examples

``` r
brreg_annotation_summary()
#> ! No annotation data. Run `brreg_sync()` first.
#> # A tibble: 0 × 3
#> # ℹ 3 variables: infotype <chr>, n_entities <int>, n_annotations <int>
```
