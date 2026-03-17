# Compute aggregate time series from snapshots

Produce period-level summary statistics from the snapshot store for any
combination of variables and summary functions. Returns a tibble
suitable for ggplot2 or
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md)
conversion.

## Usage

``` r
brreg_series(
  .vars = NULL,
  .fns = list(total = function(x) sum(x, na.rm = TRUE)),
  by = NULL,
  frequency = c("year", "quarter", "month"),
  from = NULL,
  to = NULL,
  type = c("enheter", "underenheter", "roller"),
  label = FALSE
)
```

## Arguments

- .vars:

  Character vector of column names to aggregate. `NULL` (default) counts
  entities per period.

- .fns:

  Named list of summary functions applied to each column in `.vars`.
  Default: `list(total = \(x) sum(x, na.rm = TRUE))`. Use
  `list(avg = mean, sd = sd)` for multiple summaries. Output columns are
  named `{variable}_{function}`.

- by:

  Character vector of grouping column names (e.g. `"nace_1"`,
  `c("legal_form", "municipality_code")`). `NULL` for national totals.

- frequency:

  One of `"year"`, `"quarter"`, `"month"`.

- from, to:

  Date range. Defaults to range of available snapshots.

- type:

  One of `"enheter"`, `"underenheter"`, `"roller"`.

- label:

  Logical. Translate group codes to English labels.

## Value

A tibble with `period` (character), optional grouping columns, and one
column per variable-function combination. Attribute `brreg_panel_meta`
records metadata for
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md)
conversion.

## See also

[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
for entity-level panels,
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md)
for tsibble conversion.

Other tidybrreg panel functions:
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md),
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md),
[`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md),
[`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md)

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("arrow", quietly = TRUE)
# \donttest{
brreg_series(.vars = "employees", by = "legal_form")

brreg_series(.vars = "employees",
             .fns = list(avg = mean, total = sum),
             by = "nace_1")
# }
}
```
