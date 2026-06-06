# Summarize changes by field and type

Produces a count table of how many changes occurred per field and change
type, useful for understanding the volume and distribution of registry
mutations.

## Usage

``` r
brreg_change_summary(from = NULL, to = NULL, registry = NULL)
```

## Arguments

- from, to:

  Date range (inclusive).

- registry:

  Character vector of streams to include. Default includes all four.

## Value

A tibble with `registry`, `change_type`, `field`, `n`.

## See also

[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
for raw changelog rows,
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to populate the changelog.

Other tidybrreg panel functions:
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md),
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md),
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) { # interactive()
brreg_change_summary(from = Sys.Date() - 7)
}
```
