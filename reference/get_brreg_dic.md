# Fetch a brreg dictionary

Retrieve English or Norwegian label dictionaries for NACE industry codes
(SSB classification 6, SN2007) or institutional sector codes (SSB
classification 39). Dictionaries are cached in a session-level
environment (following the eurostat package pattern), so the network is
consulted at most once per dictionary and language per session.

## Usage

``` r
get_brreg_dic(
  dictname = c("nace", "sector"),
  lang = c("en", "no"),
  source = c("auto", "klass", "bundled"),
  refresh = FALSE
)
```

## Arguments

- dictname:

  One of `"nace"` or `"sector"`.

- lang:

  `"en"` (default) for English labels or `"no"` for Norwegian.

- source:

  One of `"auto"`, `"klass"`, or `"bundled"`; see the section on network
  access.

- refresh:

  Logical. If `TRUE`, ignore the session cache and fetch again.

## Value

A tibble with columns `code`, `name` (label in the requested language),
and `level`. Attributes `source` (`"klass"` or `"bundled"`), `lang`, and
`vintage` (the date the labels were retrieved from KLASS) record where
the labels came from.

## Network access and offline use

With `source = "auto"` (default) the dictionary is requested from the
SSB KLASS API (`data.ssb.no`), which is the only source of Norwegian
labels and of codes valid today. If the request fails, the bundled
English dictionary is returned instead and a
`tidybrreg_warning_bundled_fallback` states its vintage; for
`lang = "no"` there is no bundled fallback and the error propagates.
`source = "bundled"` never touches the network and is the mode to use
offline or in tests; `options(tidybrreg.offline = TRUE)` makes it the
default for the session. `source = "klass"` requires the network and
errors when it is unavailable. The bundled dictionaries were retrieved
from KLASS on 2026-06-16 (see
[tidybrreg_provenance](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md)).

## See also

[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
for translating columns in place,
[tidybrreg_provenance](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md)
for the bundled dictionaries' sources.

Other tidybrreg utilities:
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md),
[`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md),
[`tidybrreg_conditions`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md),
[`tidybrreg_endpoints`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_endpoints.md)

## Examples

``` r
get_brreg_dic("nace", source = "bundled")
#> # A tibble: 1,783 × 3
#>    code   name                                                             level
#>    <chr>  <chr>                                                            <chr>
#>  1 01     Crop and animal production, hunting and related service activit… 2    
#>  2 01.1   Growing of non-perennial crops                                   3    
#>  3 01.11  Growing of cereals, other than rice, leguminous crops and oil s… 4    
#>  4 01.110 Growing of cereals, other than rice, leguminous crops and oil s… 5    
#>  5 01.12  Growing of rice                                                  4    
#>  6 01.120 Growing of rice                                                  5    
#>  7 01.13  Growing of vegetables and melons, roots and tubers               4    
#>  8 01.130 Growing of vegetables and melons, roots and tubers               5    
#>  9 01.14  Growing of sugar cane                                            4    
#> 10 01.140 Growing of sugar cane                                            5    
#> # ℹ 1,773 more rows
attr(get_brreg_dic("sector", source = "bundled"), "vintage")
#> [1] "2026-06-16"
if (FALSE) { # interactive() && curl::has_internet()
get_brreg_dic("nace", lang = "no")
}
```
