# Parse brreg RFC 6902 JSON Patch operations into a tibble

Collector-based with pre-allocated vectors. Used by
[`parse_updates_page()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_updates_page.md)
and the sync engine. For the flat-output path,
[`flatten_page_patches()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_page_patches.md)
is used instead.

## Usage

``` r
parse_patch(endringer)
```

## Arguments

- endringer:

  List of patch operations from the brreg API.

## Value

A tibble with columns `operation`, `field`, `new_value`.

## Details

RFC 6902 `move` operations emit two rows: an add/replace at the
destination path and a `remove` at the source path (from `$from`).
`copy` operations emit one row at the destination.
