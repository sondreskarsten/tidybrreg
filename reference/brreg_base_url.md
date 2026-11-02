# Base URL for a brreg API service

The services share the `data.brreg.no` host but live under different
path roots: the Enhetsregisteret REST API, the Fullmakt (signature and
procuration) service and the Regnskapsregisteret accounts API.

## Usage

``` r
brreg_base_url(
  service = c("enhetsregisteret", "fullmakt", "regnskapsregisteret")
)
```

## Arguments

- service:

  One of `"enhetsregisteret"`, `"fullmakt"` or `"regnskapsregisteret"`.
