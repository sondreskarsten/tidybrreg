# Base URL for a brreg API service

Both services share the `data.brreg.no` host but live under different
path roots: the Enhetsregisteret REST API and the Fullmakt (signature
and procuration) service.

## Usage

``` r
brreg_base_url(service = c("enhetsregisteret", "fullmakt"))
```

## Arguments

- service:

  One of `"enhetsregisteret"` or `"fullmakt"`.
