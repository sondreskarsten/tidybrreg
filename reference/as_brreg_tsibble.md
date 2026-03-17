# Convert tidybrreg output to tsibble

Convert the output of
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
or
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)
to a tsibble for use with the tidyverts ecosystem (fable, feasts,
slider). Uses `regular = FALSE` since brreg snapshots are irregularly
spaced.

## Usage

``` r
as_brreg_tsibble(x, key = NULL, index = NULL)
```

## Arguments

- x:

  A tibble from
  [`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
  or
  [`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md).

- key:

  Character vector of key column(s). For panels, typically `"org_nr"`.
  For series, the grouping variable (e.g. `"legal_form"`). If `NULL`,
  inferred from the `brreg_panel_meta` attribute.

- index:

  Character. Name of the time index column. Default `"period"` for
  series output, `"snapshot_date"` for panel output.

## Value

A tsibble.

## See also

[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md).

Other tidybrreg panel functions:
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md),
[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("tsibble", quietly = TRUE)
# \donttest{
panel <- brreg_panel(cols = c("employees", "legal_form"))
as_brreg_tsibble(panel)
# }
}
```
