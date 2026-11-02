# Map the unsupported-accounting-plan response to a typed empty result

Regnskapsregisteret answers HTTP 500 with the message
`oppstillingsplan som ikke er støttet (PLAN)` (also seen spelled
`stottet`) for entities whose accounting plan it does not serve.

## Usage

``` r
regnskap_unsupported(resp, org_nr, empty, call = rlang::caller_env())
```

## Value

`NULL` unless the response is that case, otherwise the typed empty with
attributes `http_status`, `unsupported_plan` and a
`tidybrreg_warning_unsupported_plan`.
