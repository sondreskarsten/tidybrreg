# Parse a BRREG calendar date

BRREG emits dates as ISO `YYYY-MM-DD` on the Enhetsregisteret API and as
`DD.MM.YYYY` on the Fullmakt service and in the CSV variant of the
konsernstruktur endpoint. Both forms are accepted; anything else becomes
`NA` and is counted by the caller as a parse problem.

## Usage

``` r
parse_brreg_date(x)
```

## Arguments

- x:

  Character vector.

## Value

A `Date` vector of the same length.
