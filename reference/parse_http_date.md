# Parse an HTTP-date header as UTC

`Last-Modified` and `Date` headers use the RFC 7231 IMF-fixdate form,
which is always GMT. Parsed with the `C` locale so weekday and month
names are recognised regardless of the session locale.

## Usage

``` r
parse_http_date(x)
```

## Arguments

- x:

  Character vector of header values.

## Value

A `POSIXct` vector in the `UTC` time zone.
