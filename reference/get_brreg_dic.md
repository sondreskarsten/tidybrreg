# Fetch a brreg dictionary

Retrieve English or Norwegian label dictionaries for NACE industry codes
or institutional sector codes. Dictionaries are cached in a
session-level environment (following the eurostat package pattern).
Bundled data is used as fallback when the SSB Klass API is unreachable.

## Usage

``` r
get_brreg_dic(dictname = c("nace", "sector"), lang = "en")
```

## Arguments

- dictname:

  One of `"nace"` or `"sector"`.

- lang:

  `"en"` (default) for English labels or `"no"` for Norwegian.

## Value

A tibble with columns `code`, `name_en`, `level`.

## See also

Other tidybrreg utilities:
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md),
[`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
get_brreg_dic("nace")
get_brreg_dic("sector")
}
```
