# Build the rows of a parse-problem table for one column

At most `max_rows` failures are listed, taken from the same indices for
`row` and `actual` so the two columns always agree; `n_failed` carries
the total count.

## Usage

``` r
parse_problem_rows(col, type, original, failed, max_rows = 20L)
```
