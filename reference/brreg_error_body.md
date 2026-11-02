# Extract error messages from brreg API error responses

Enhetsregisteret answers a rejected request with a Norwegian error body
(`feilmelding`, `valideringsfeil[].feilmelding` with the offending
`parametere`); older and other services use
`validationErrors[].errorMessage`, `error` and `trace`. Every form is
read so the `tidybrreg_error_http` carries what the register said.

## Usage

``` r
brreg_error_body(resp)
```

## Arguments

- resp:

  An httr2 response object.
