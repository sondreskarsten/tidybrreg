# Translate codes to human-readable English labels

Replace coded values in a brreg tibble with English descriptions,
following the eurostat package's `label_eurostat()` pattern. Works on
both data frames and character vectors.

## Usage

``` r
brreg_label(x, dic = NULL, code = NULL, lang = "en")
```

## Arguments

- x:

  A tibble from
  [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
  [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
  or
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
  or a character vector of codes.

- dic:

  A character string naming the dictionary to use when `x` is a
  character vector. One of `"legal_form"`, `"nace"`, `"sector"`,
  `"role"`, `"role_group"`. Ignored when `x` is a data frame
  (dictionaries are inferred from column names).

- code:

  For data frames: character vector of column names for which to retain
  the original code alongside the label. A column with suffix `_code` is
  added. For example, `brreg_label(x, code = "legal_form")` adds
  `legal_form_code`.

- lang:

  Language for NACE and sector labels. `"en"` (default) or `"no"`
  (Norwegian original from brreg API).

## Value

When `x` is a data frame: the same tibble with code columns replaced by
English labels. When `x` is a character vector: a character vector of
labels.

## See also

[legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md),
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
for bundled reference data,
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)
for fetching fresh dictionaries.

Other tidybrreg utilities:
[`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md),
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)

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
}
```
