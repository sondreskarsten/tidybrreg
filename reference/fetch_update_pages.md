# Read pages from an enheter/underenheter update feed

Shared paginator for
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
and
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md).
The first page is addressed by `dato`, later pages by the exclusive
cursor `oppdateringsid = max(update_id) + 1`.

## Usage

``` r
fetch_update_pages(
  type,
  since,
  size,
  max_pages,
  include_changes = FALSE,
  verbose = FALSE
)
```

## Value

A list with `pages` (raw update objects per page), `complete`,
`pages_fetched`, `cursor`, `type`.
