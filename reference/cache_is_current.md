# Decide whether a cached bulk file is provably current

Sends a HEAD request and compares `ETag` and `Last-Modified` with the
sidecar written at download time. `TRUE` only when at least one
validator is present on both sides and every validator present on both
sides matches; a missing sidecar, a server that sends no validator, or a
failed HEAD all yield `FALSE` (re-download).

## Usage

``` r
cache_is_current(url, meta_file)
```
