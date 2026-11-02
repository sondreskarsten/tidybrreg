# Abort on an HTTP error response

Abort on an HTTP error response

## Usage

``` r
abort_http(resp, endpoint, call = rlang::caller_env())
```

## Arguments

- resp:

  An httr2 response with status 400 or above.

- endpoint:

  Path that was requested (for the condition fields).
