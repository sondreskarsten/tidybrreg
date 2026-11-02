# Perform a brreg request without raising on HTTP error status

Every endpoint wrapper inspects the status itself so that 404, 410 and
server errors can be mapped to the typed conditions documented in
[tidybrreg_conditions](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md).
The retry policy of
[`brreg_http_req()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_http_req.md)
still applies to HTTP responses; a connection failure (`httr2_failure`:
DNS, TCP, TLS or a dropped connection) is retried here with the same
number of attempts and an exponential pause, then aborts with a
`tidybrreg_error_connection`. The register's rate limit answered as HTTP
200 (`text/plain` `Too many requests`), still present after the retries,
aborts with a `tidybrreg_error_rate_limited` instead of failing later as
an unreadable body.

## Usage

``` r
brreg_perform(req, call = rlang::caller_env(), path = NULL)
```

## Arguments

- req:

  An httr2 request.

- path:

  Optional file path; the body is streamed to it as
  [`httr2::req_perform()`](https://httr2.r-lib.org/reference/req_perform.html)
  does, so a bulk download that drops its connection is retried like any
  other request.
