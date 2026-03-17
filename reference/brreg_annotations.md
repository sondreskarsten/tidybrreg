# Retrieve registry annotations (påtegninger) for entities

Påtegninger are public annotations placed on entities by the register
keeper to warn third parties of irregularities. Requires
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to have been run.

## Usage

``` r
brreg_annotations(org_nr = NULL, infotype = NULL, active_only = TRUE)
```

## Arguments

- org_nr:

  Optional character vector of organisation numbers. `NULL` returns all
  annotations.

- infotype:

  Optional character vector of annotation type codes to filter by (e.g.
  `"FADR"`, `"NAVN"`).

- active_only:

  Logical. If `TRUE` (default), return only annotations currently in
  force.

## Value

A tibble with columns: `org_nr`, `position` (array index), `infotype`,
`tekst` (annotation text), `innfoert_dato` (date introduced).

## See also

[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to populate annotation data,
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
to track annotation events over time.

Other tidybrreg data management functions:
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md),
[`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md)

## Examples

``` r
if (FALSE) { # interactive()
# \donttest{
brreg_sync()
brreg_annotations()
# }
}
```
