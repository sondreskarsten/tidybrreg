# Flatten a Regnskapsregisteret response to one nested row per filing

Each filing is flattened with
[`flatten_json()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_json.md).
Leaves inside the statement objects become the filing's `items` table
([`build_items()`](https://sondreskarsten.github.io/tidybrreg/reference/build_items.md));
the other leaves are renamed through `regnskap_dict`
([regnskap_maps](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_maps.md))
by
[`rename_from_dict()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_from_dict.md)
(observed fields only, unmapped leaves as snake_case) and coerced by
[`coerce_types()`](https://sondreskarsten.github.io/tidybrreg/reference/coerce_types.md)
with the shared reported-failure rule. The identities are checked
([`check_identities()`](https://sondreskarsten.github.io/tidybrreg/reference/check_identities.md)),
the filings are bound, and the per-filing parse problems (scalar columns
and `items.value`) are re-indexed by filing and attached once as
`brreg_parse_problems` with one `tidybrreg_warning_parse`. The queried
`org_nr` fills the column only when the filing carries no
`virksomhet.organisasjonsnummer`.

## Usage

``` r
flatten_regnskap(raw, org_nr)
```

## Arguments

- raw:

  Parsed JSON list (array of filings).

- org_nr:

  Organization number that was queried.
