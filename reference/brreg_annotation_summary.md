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
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md),
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md),
[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md),
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md),
[`read_changelog()`](https://sondreskarsten.github.io/tidybrreg/reference/read_changelog.md)

## Examples

``` r
if (FALSE) { # interactive()
brreg_annotation_summary()
}
```
