# Retrieve field-level CDC changes as a flat tibble

Returns one row per field-level change, plus one synthetic row for each
event that carries no field patches (Ny, Sletting, Fjernet). Synthetic
rows have `operation = NA`, `field = NA`, `new_value = NA`, preserving
event-level metadata in the output.

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

  Date or POSIXct. Return updates after this timestamp. Defaults to
  yesterday.

- size:

  Integer. Number of updates per page (max 10000).

- max_pages:

  Integer. Maximum pages to fetch. Default 1. Set higher to paginate
  through large result sets automatically.

- type:

  One of `"enheter"`, `"underenheter"`, or `"roller"`. Roller uses
  CloudEvents format; `include_changes` is ignored.

- verbose:

  Logical. Print page-level progress.

## Value

A tibble with columns: `update_id`, `org_nr`, `change_type`,
`timestamp`, `operation`, `field`, `new_value`. No list-columns. Events
without field patches (Ny, Sletting, Fjernet) appear as rows with
`operation`, `field`, and `new_value` all `NA`.

## Details

To retrieve initial field values for newly registered entities
(change_type `"Ny"`), call
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
per org_nr — the CDC payload for Ny events contains no field-level
patches.

## See also

[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
for the event-level view.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
brreg_update_fields(since = Sys.Date() - 1, size = 50)
}
```
