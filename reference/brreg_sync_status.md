# Display sync status

Shows the current state of the sync engine: which state files exist,
when the last sync occurred, cursor positions, and changelog size.

## Usage

``` r
brreg_sync_status()
```

## Value

A list with status components (invisibly).

## See also

[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to run a sync,
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
to query the changelog.

Other tidybrreg data management functions:
[`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md),
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md),
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md),
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md),
[`read_changelog()`](https://sondreskarsten.github.io/tidybrreg/reference/read_changelog.md)

## Examples

``` r
brreg_sync_status()
#> 
#> ── tidybrreg sync status ──
#> 
#> Last sync: NA
#> Cursor positions: enheter=0, underenheter=0, roller=0
#> ! enheter: not initialized
#> ! underenheter: not initialized
#> ! roller: not initialized
#> ! paategninger: not initialized
#> Changelog: 0 partition(s), 0 file(s)
```
