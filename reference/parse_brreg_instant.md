# Parse an ISO 8601 instant as UTC

BRREG timestamps (`dato` on the enheter/underenheter update feeds,
`time` on the roller CloudEvents feed) are UTC instants, with or without
fractional seconds and with or without a trailing `Z`. They are parsed
as UTC regardless of the session time zone so a value round-trips
identically on every machine.

## Usage

``` r
parse_brreg_instant(x)
```

## Arguments

- x:

  Character vector.

## Value

A `POSIXct` vector in the `UTC` time zone.
