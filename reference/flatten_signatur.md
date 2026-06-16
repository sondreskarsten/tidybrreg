# Flatten a Fullmakt signature/procuration response to a tibble

Flatten a Fullmakt signature/procuration response to a tibble

## Usage

``` r
flatten_signatur(raw, org_nr, signature_type)
```

## Arguments

- raw:

  Parsed JSON list from a signatur or prokura endpoint.

- org_nr:

  Organization number (passed through to output).

- signature_type:

  `"signatur"` or `"prokura"`.
