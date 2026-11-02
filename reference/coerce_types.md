# Coerce columns to declared types from field_dict

Applied to every dictionary column present in `tbl`. Failures are
attached as the `brreg_parse_problems` attribute and signalled once as a
`tidybrreg_warning_parse`.

## Usage

``` r
coerce_types(tbl, dict = field_dict)
```

## Arguments

- tbl:

  A tibble from
  [`rename_from_dict()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_from_dict.md).

- dict:

  The field map whose types apply:
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
  (default) or `regnskap_dict`.
