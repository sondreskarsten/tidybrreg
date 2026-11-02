# Translate codes to human-readable labels

Replace coded values in a brreg tibble with English (or Norwegian)
descriptions, following the eurostat package's `label_eurostat()`
pattern. Works on both data frames and character vectors.

## Usage

``` r
brreg_label(x, dic = NULL, code = NULL, lang = c("en", "no"))
```

## Arguments

- x:

  A tibble from
  [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
  [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
  or
  [`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
  or a character vector of codes.

- dic:

  A character string naming the dictionary to use when `x` is a
  character vector. One of `"legal_form"`, `"nace"`, `"sector"`,
  `"role"`, `"role_group"`, `"regnskap_item"`, `"regnskap_group"`.
  Ignored when `x` is a data frame (dictionaries are inferred from
  column names).

- code:

  For data frames: character vector of column names for which to retain
  the original code alongside the label. A column with suffix `_code` is
  added before the label column. For example,
  `brreg_label(x, code = "legal_form")` adds `legal_form_code`.

- lang:

  Language for labels: `"en"` (default) or `"no"` (Norwegian, as
  published by BRREG and SSB).

## Value

When `x` is a data frame: the same tibble with code columns replaced by
labels. When `x` is a character vector: a character vector of labels,
without names.

## Which columns are labelled

`legal_form` (from
[legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md)),
`role_code` (from
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)),
`role_group_code` (from
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)),
`nace_1`, `nace_2`, `nace_3` and `sector_code` (from the NACE and
institutional-sector dictionaries of
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)),
and the accounts columns `item` (from
[regnskap_items](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md)),
`group` and `statement` (from
[regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)),
inside a nested `items` list-column as well as on an unnested table.
Other columns are never touched. Codes with no dictionary entry pass
through unchanged, and labels are not codes, so applying `brreg_label()`
twice is the same as applying it once. Attributes of the input (such as
`total_matches` from
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md))
are preserved.

## Network access

Legal-form and role dictionaries are bundled and never need the network.
NACE and sector dictionaries come from the SSB KLASS API on first use in
a session and are cached for the session; when KLASS cannot be reached,
or `options(tidybrreg.offline = TRUE)` is set, the bundled English
dictionaries are used instead and the result carries their vintage. See
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)
for the full policy.

## See also

[legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md),
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md),
[regnskap_items](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md),
[regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)
for bundled reference data,
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)
for fetching fresh dictionaries.

Other tidybrreg utilities:
[`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md),
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md),
[`tidybrreg_conditions`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md),
[`tidybrreg_endpoints`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_endpoints.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
eq <- brreg_entity("923609016")

# Label all code columns
brreg_label(eq)

# Keep original codes alongside labels
brreg_label(eq, code = "legal_form")

# Label a character vector directly
brreg_label(c("AS", "ASA", "ENK"), dic = "legal_form")
brreg_label(c("AS", "ASA", "ENK"), dic = "legal_form", lang = "no")
brreg_label(c("total_assets", "net_income"), dic = "regnskap_item", lang = "no")
}
```
