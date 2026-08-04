# Flatten a recursive konsernstruktur response to one row per node

Unlike the depth-2-bounded structures elsewhere in the package (roles,
signatur), the konsern tree nests `children` to arbitrary depth, so this
walks recursively, reusing the recursive-helper + emit-callback shape of
[`flatten_value_into()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_value_into.md).
Observed values win over derived ones: `nivaa`,
`parentOrganisasjonsnummer`, and `parentNavn` are taken from the node
when present and only filled from recursion context when absent (the
root).

## Usage

``` r
flatten_konsern(raw, org_nr)
```

## Arguments

- raw:

  Parsed JSON list from the konsernstruktur endpoint.

- org_nr:

  Organization number (passed through to output).
