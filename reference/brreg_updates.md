# Retrieve incremental entity updates

Query the brreg change data capture (CDC) endpoint for entities modified
since a given date. Each update carries a monotonically increasing
`update_id` suitable for cursor-based pagination and deduplication.

## Usage

``` r
brreg_updates(
  since = Sys.Date() - 1,
  size = 100,
  include_changes = FALSE,
  type = c("enheter", "underenheter", "roller")
)
```

## Arguments

- since:

  Date or POSIXct. Return updates after this timestamp. Defaults to
  yesterday.

- size:

  Integer. Number of updates to fetch (max 10000).

- include_changes:

  Logical. If `TRUE`, include field-level change details per update as a
  list-column of tibbles. The brreg API returns changes in a flat RFC
  6902-style JSON Patch format.

- type:

  One of `"enheter"` (main entities), `"underenheter"` (sub-entities),
  or `"roller"` (role assignments). Roller updates use CloudEvents
  format (`afterTime`/`afterId` pagination) rather than the HAL-based
  format used by enheter/underenheter. `include_changes` is ignored for
  roller.

## Value

A tibble with columns: `update_id` (integer), `org_nr` (character),
`change_type` (character: Ny/Endring/Sletting), `timestamp` (POSIXct).
If `include_changes = TRUE`, an additional list-column `changes`
contains tibbles with columns `operation`, `field`, `new_value`.

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
to fetch the current state of a changed entity.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_updates(since = Sys.Date() - 1, size = 10)

# With field-level change details
brreg_updates(since = Sys.Date() - 1, size = 5, include_changes = TRUE)
}
```
