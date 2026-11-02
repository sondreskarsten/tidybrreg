# The unsupported-accounting-plan message of an HTTP 500, or `NA`

Shared by
[`regnskap_unsupported()`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_unsupported.md)
and the retry rule
[`is_transient_response()`](https://sondreskarsten.github.io/tidybrreg/reference/is_transient_response.md),
so the one 500 that is a property of the entity is neither retried nor
reported as a server error.

## Usage

``` r
unsupported_plan_message(resp)
```
