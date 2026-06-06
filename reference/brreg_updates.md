# Retrieve incremental entity updates

Query the brreg change data capture (CDC) endpoint for entities modified
since a given date. Each update carries a monotonically increasing
`update_id` suitable for cursor-based pagination and deduplication.

## Usage

``` r
brreg_updates(
  since = Sys.Date() - 1,
  size = 100,
  max_pages = 1L,
  include_changes = FALSE,
  type = c("enheter", "underenheter", "roller"),
  verbose = FALSE
)
```

## Arguments

- since:

  Date or POSIXct. Return updates after this timestamp. Defaults to
  yesterday.

- size:

  Integer. Number of updates per page (max 10000).

- max_pages:

  Integer. Maximum pages to fetch. Default 1. Set higher to paginate
  through large result sets automatically.

- include_changes:

  Logical. If `TRUE`, include field-level change details per update as a
  list-column of tibbles.

- type:

  One of `"enheter"`, `"underenheter"`, or `"roller"`. Roller uses
  CloudEvents format; `include_changes` is ignored.

- verbose:

  Logical. Print page-level progress.

## Value

A tibble with columns: `update_id`, `org_nr`, `change_type`,
`timestamp`. If `include_changes = TRUE`, a list-column `changes` with
tibbles of `operation`, `field`, `new_value`.

## See also

[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md)
for a flat alternative.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_updates(since = Sys.Date() - 1, size = 10)

# Auto-paginate
brreg_updates(since = "2026-03-01", size = 10000, max_pages = 50,
              verbose = TRUE)
}
```
