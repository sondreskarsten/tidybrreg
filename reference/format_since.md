# Format a `since` argument for the update feeds

A `POSIXct` keeps its full precision and is rendered in UTC; a `Date` is
the start of that day in UTC; a character value is parsed with
[`parse_brreg_instant()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_brreg_instant.md)
(ISO date or date-time). The result is the `YYYY-MM-DDTHH:MM:SS.sssZ`
form the feeds expect.

## Usage

``` r
format_since(since)
```

## Arguments

- since:

  Date, POSIXct, or character.

## Value

A length-1 character string.
