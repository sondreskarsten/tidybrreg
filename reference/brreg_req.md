# Build an httr2 request to a brreg API service

Build an httr2 request to a brreg API service

## Usage

``` r
brreg_req(path, query = list(), service = c("enhetsregisteret", "fullmakt"))
```

## Arguments

- path:

  URL path appended to the base URL.

- query:

  Named list of query parameters.

- service:

  One of `"enhetsregisteret"` or `"fullmakt"`.
