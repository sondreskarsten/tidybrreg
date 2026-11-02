# Map the status of a satellite endpoint response to a result

The per-entity satellite endpoints (roles, legal roles, konsern,
signatur, prokura) share one status contract, documented in
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md):
HTTP 200 is parsed by the caller; HTTP 404 (the entity does not exist,
or has nothing registered at this endpoint) yields the typed empty
result with attribute `http_status = 404L` and no warning; HTTP 410
yields the typed empty with `http_status = 410L` and a
`tidybrreg_warning_deleted`; any other status of 400 or above aborts
with a `tidybrreg_error_http`.

## Usage

``` r
satellite_status(resp, endpoint, org_nr, empty, call = rlang::caller_env())
```

## Arguments

- resp:

  An httr2 response.

- endpoint:

  Requested path, for condition fields.

- org_nr:

  Organization number, for condition fields.

- empty:

  The typed zero-row tibble for the endpoint.

## Value

`NULL` when the caller should parse the body, otherwise the result to
return.
