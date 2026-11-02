# Fetch roller updates (CloudEvents format)

The roller feed is addressed by `afterTime` for the first page and by
`afterId` (the last event id read) for later pages.

## Usage

``` r
brreg_updates_roller(since, size, max_pages = 1L, verbose = FALSE)
```
