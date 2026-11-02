# Typed empty for a rule the Fullmakt service declines to resolve

The service answers HTTP 200 without `signeringsKombinasjon` and with
`status.rutineStatus` (code `NA`, "Generelle unntak, finnes roller som
har status det ikke kan foretas maskinelt oppslag mot") when a rule is
registered but cannot be resolved mechanically. That is neither "nothing
registered" nor an error: the typed empty is returned with attributes
`http_status = 200L`, `routine_status` and `routine_text`, and a
`tidybrreg_warning_unresolved` is signalled.

## Usage

``` r
unresolved_signatur(
  org_nr,
  signature_type,
  routine,
  call = rlang::caller_env()
)
```
