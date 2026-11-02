# Retrieve incremental entity updates

Query the brreg change data capture (CDC) endpoint for entities modified
since a given instant. Each update carries a monotonically increasing
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

  Date, POSIXct, or ISO 8601 string. Return updates at or after this
  instant. Defaults to yesterday (midnight UTC).

- size:

  Integer. Number of updates per page (max 10000).

- max_pages:

  Integer. Maximum pages to fetch. Default 1. Set higher to paginate
  through large result sets automatically.

- include_changes:

  Logical. If `TRUE`, include field-level change details per update as a
  list-column of tibbles. Not available for `type = "roller"`, whose
  feed carries no field patches; supplying `TRUE` there is an error.

- type:

  One of `"enheter"`, `"underenheter"`, or `"roller"`. The roller feed
  uses the CloudEvents format and reports only which entity's roles
  changed; fetch the new state with
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md).

- verbose:

  Logical. Print page-level progress.

## Value

A tibble with columns: `update_id` (integer), `org_nr`, `change_type`,
`timestamp` (POSIXct, UTC). If `include_changes = TRUE`, a list-column
`changes` with tibbles of `operation`, `field`, `path`, `new_value`. An
empty feed yields a zero-row tibble with the same typed columns.

## Time handling

`since` is sent to the feed as a UTC instant. A `POSIXct` keeps its full
precision; a `Date` is midnight UTC of that day; an ISO 8601 string
(`"2026-03-01"` or `"2026-03-01T14:00:00Z"`) is parsed as UTC.
Timestamps in the result are `POSIXct` in the `UTC` time zone, whatever
the session time zone.

## Completeness

The feed is read page by page until a page is short, the feed is
exhausted, or `max_pages` is reached. The result carries attributes
`complete` (`FALSE` when `max_pages` stopped the read while the last
page was full, or a later page failed), `pages_fetched`, and `cursor`
(the last `update_id` read; pass `update_id + 1` as the next cursor to
resume). Stopping on `max_pages` signals a
`tidybrreg_warning_truncated`; a failure after the first page signals a
`tidybrreg_warning_partial` and returns the pages already read; a
failure on the first page aborts with a `tidybrreg_error_http`.

## Unknown members

Any member of an update object that the package does not model is passed
through as a column named by its snake_case key, and the result carries
attribute `unknown_members` plus a single
`tidybrreg_warning_unknown_member`, so an upstream addition cannot
vanish silently.

## See also

[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md)
for a flat alternative,
[tidybrreg_conditions](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md)
for the conditions signalled.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
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
