# Collapse an observed array value to a single character cell

BRREG returns addresses, `vedtektsfestetFormaal`, and `aktivitet` as
arrays of register line-fragments. Element text routinely contains
commas and semicolons but never newlines, so `"\n"` is the only
separator that survives a round trip: a consumer can split it back into
the observed elements, which `"; "` and `", "` do not allow. Arrays
whose elements are objects (`historiskeNavn`, `paategninger`) have no
meaningful text join and are serialized to JSON instead, preserving
field structure.

## Usage

``` r
collapse_observed(val)
```

## Arguments

- val:

  A list or atomic vector taken from a parsed response.

## Value

A length-1 character value.

## Details

Note that the CSV bulk is BRREG's own flattening and uses field-specific
separators (newline for addresses, space for wrapped text such as
`vedtektsfestetFormaal`), so CSV-sourced and JSON-sourced values for
those fields are not byte-identical and cannot be made so without
imposing a per-field rule.
