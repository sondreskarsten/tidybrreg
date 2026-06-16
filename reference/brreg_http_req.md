# Build an httr2 request with the shared tidybrreg configuration

Centralises the user agent, transient-retry policy, and per-host
throttle so every request the package makes is constructed identically.
Host-specific concerns (base URL, throttle realm, Accept header, error
body extractor) are supplied by the caller.

## Usage

``` r
brreg_http_req(
  base_url,
  path,
  query = list(),
  realm,
  rate = 5,
  accept = "application/json;charset=UTF-8",
  error_body = NULL
)
```

## Arguments

- base_url:

  Host base URL.

- path:

  URL path appended to `base_url`.

- query:

  Named list of query parameters.

- realm:

  Throttle realm. One bucket per host so distinct hosts do not share a
  rate limit.

- rate:

  Maximum sustained requests per second for `realm`.

- accept:

  Value of the `Accept` header.

- error_body:

  Optional function mapping a response to error messages, passed to
  [`httr2::req_error()`](https://httr2.r-lib.org/reference/req_error.html).
