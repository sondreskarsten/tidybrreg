# Compute field-level diffs between two roller state tibbles

Pure function: takes two flattened roller tibbles (as produced by
[`flatten_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles.md)
or
[`parse_roles_bulk()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_roles_bulk.md))
and returns a long-format changelog recording every field-level
mutation. Detects three categories of change: role additions, role
removals, and field-level modifications on continuing roles.

## Usage

``` r
diff_roller_state(
  old_state,
  new_state,
  timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
  update_id = NA_integer_
)
```

## Arguments

- old_state:

  Tibble. Previous roller state from
  [`read_state()`](https://sondreskarsten.github.io/tidybrreg/reference/read_state.md)
  or an earlier
  [`flatten_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles.md)
  call. `NULL` or zero-row tibble treats all current roles as additions.

- new_state:

  Tibble. Current roller state from
  [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
  or
  [`flatten_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles.md).

- timestamp:

  Character or POSIXct. Timestamp for changelog entries (typically the
  CDC event time or sync time).

- update_id:

  Integer or character. Identifier for the sync batch, used as
  `update_id` in the changelog.

## Value

A tibble matching the changelog schema: `timestamp`, `org_nr`,
`registry` (always `"roller"`), `change_type` (`"entry"`, `"exit"`,
`"change"`), `field`, `value_from`, `value_to`, `update_id`.

## Composite key

Each role assignment is identified by
`(org_nr, role_group_code, role_code, holder_id)` where `holder_id` is
derived from `person_id` for person-held roles and
`entity:{entity_org_nr}` for entity-held roles (auditors, accountants).
Roles with neither are keyed as `unknown:{row_index}` within their
respective state — these are rare and produce conservative add/remove
pairs rather than false modifications.

## NA handling

For additions, fields that are `NA` in the new state are excluded from
the changelog (no value to report). For removals, fields that are `NA`
in the old state are excluded. For modifications, a change from `NA` to
a non-NA value (or vice versa) is recorded.

## See also

[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
for automated sync with changelog persistence,
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
for fetching current roles,
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
for querying stored changelogs.

Other tidybrreg data management functions:
[`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md),
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md),
[`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md),
[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md),
[`read_changelog()`](https://sondreskarsten.github.io/tidybrreg/reference/read_changelog.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# Detect board changes for a single company
old <- brreg_roles("923609016")
Sys.sleep(1)
new <- brreg_roles("923609016")
diff_roller_state(old, new)

# Bootstrap: NULL old state treats all roles as entries
roles <- brreg_roles("923609016")
diff_roller_state(NULL, roles)
}
```
