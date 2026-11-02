# Retrieve field-level CDC changes as a flat tibble

Returns one row per field-level change, plus one synthetic row for each
event that carries no field patches (Ny, Sletting, Fjernet). Synthetic
rows have `operation = NA`, `field = NA`, `path = NA`, `new_value = NA`,
preserving event-level metadata in the output.

## Usage

``` r
brreg_update_fields(
  since = Sys.Date() - 1,
  size = 100,
  max_pages = 1L,
  type = c("enheter", "underenheter"),
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

- type:

  One of `"enheter"` or `"underenheter"`.

- verbose:

  Logical. Print page-level progress.

## Value

A tibble with columns: `update_id`, `org_nr`, `change_type`, `timestamp`
(POSIXct, UTC), `operation`, `field`, `path`, `new_value`. No
list-columns. Events without field patches appear as rows with
`operation`, `field`, `path` and `new_value` all `NA`.

## Details

Patches are RFC 6902 operations. Nested values are flattened to one row
per leaf; `path` keeps the raw JSON pointer of the leaf (for example
`/forretningsadresse/adresse/0`) and `field` its snake_case rendering,
so the register's own representation is never lost. A `move` emits an
add at the destination and a `remove` at the source.

To retrieve initial field values for newly registered entities
(change_type `"Ny"`), call
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
per org_nr — the CDC payload for Ny events contains no field-level
patches.

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

[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
for the event-level view.

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
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_update_fields(since = Sys.Date() - 1, size = 50)
}
```
