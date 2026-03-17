# Prepare firm survival data

Compute time-to-event and censoring indicators from entity registration
data, ready for use with
[`survival::Surv()`](https://rdrr.io/pkg/survival/man/Surv.html) and
`flexsurv`.

## Usage

``` r
brreg_survival_data(
  data,
  entry_var = "founding_date",
  censoring_date = Sys.Date()
)
```

## Arguments

- data:

  A tibble from
  [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
  [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
  or
  [`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md).
  Must contain at least `org_nr` and a date column for entry.

- entry_var:

  Column name for the entry date. Default `"founding_date"`
  (stiftelsesdato).

- censoring_date:

  Date at which surviving firms are right-censored. Default: today.

## Value

A tibble with added columns: `entry_date`, `exit_date` (Date or NA),
`duration_years` (numeric), `event` (integer: 1 = exit observed, 0 =
right-censored). Compatible with
`survival::Surv(duration_years, event)`.

## See also

[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
for full register data.

Other tidybrreg governance functions:
[`brreg_board_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_network.md),
[`brreg_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_network.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# \donttest{
firms <- brreg_search(legal_form = "AS", municipality_code = "0301",
                       max_results = 100)
surv <- brreg_survival_data(firms)
surv[, c("org_nr", "entry_date", "exit_date", "duration_years", "event")]
# }
}
```
