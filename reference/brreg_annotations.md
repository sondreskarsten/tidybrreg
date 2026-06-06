# Retrieve registry annotations (påtegninger) for entities

Påtegninger are public annotations placed on entities by the register
keeper to warn third parties of irregularities — missing board members,
undelivered accounts, deceased officers. They are the earliest formal
signal that an entity is in regulatory trouble, preceding forced
dissolution warnings by weeks to months.

## Usage

``` r
brreg_annotations(
  org_nr = NULL,
  infotype = NULL,
  active_only = TRUE,
  translate = FALSE
)
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
  force. If `FALSE`, include cleared annotations from the changelog.

- translate:

  Logical. If `TRUE`, add an `infotype_desc` column with English
  descriptions from
  [annotation_infotypes](https://sondreskarsten.github.io/tidybrreg/reference/annotation_infotypes.md);
  unknown codes pass through unchanged. Default `FALSE`.

## Value

A tibble with columns: `org_nr`, `position` (array index), `infotype`,
`tekst` (annotation text), `innfoert_dato` (date introduced). With
`translate = TRUE`, an `infotype_desc` column is inserted after
`infotype`.

## Details

Requires
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to have been run at least once to populate the local påtegninger state.

## See also

[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
to populate annotation data,
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
to track annotation events over time,
[annotation_infotypes](https://sondreskarsten.github.io/tidybrreg/reference/annotation_infotypes.md)
for the English `infotype` lookup table.

Other tidybrreg data management functions:
[`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md),
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md),
[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md),
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md),
[`read_changelog()`](https://sondreskarsten.github.io/tidybrreg/reference/read_changelog.md)

## Examples

``` r
if (FALSE) { # interactive()
# \donttest{
brreg_sync()
brreg_annotations()
brreg_annotations(infotype = "FADR")
brreg_annotations(translate = TRUE)
# }
}
```
