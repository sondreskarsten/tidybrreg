# Is a response one the register will answer differently next time?

The retry rule shared by every request: HTTP 429 and 503, the server
errors 500, 502 and 504, and the register's rate limit when it arrives
as HTTP 200 with a `text/plain` body `Too many requests` (observed by
brreg-json-fetcher and reproduced here). A 500 whose message says the
accounting plan is unsupported
([`unsupported_plan_message()`](https://sondreskarsten.github.io/tidybrreg/reference/unsupported_plan_message.md))
is a property of the entity, not a transient failure, and is not
retried.

## Usage

``` r
is_transient_response(resp)
```

## Arguments

- resp:

  An httr2 response.

## Value

Logical scalar.
