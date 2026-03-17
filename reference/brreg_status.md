# Check availability of local bulk datasets

Inspects the snapshot store and download cache for each requested
dataset type. Used internally by
[`brreg_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_network.md)
to gate depth \> 1 operations that require local data for
person-to-entity reverse lookups.

## Usage

``` r
brreg_status(datasets = c("enheter", "underenheter", "roller"), quiet = FALSE)
```

## Arguments

- datasets:

  Character vector of dataset types to check.

- quiet:

  Logical. If `TRUE`, suppress informational messages.

## Value

A list with components: `available` (character vector of datasets found
locally), `missing` (character vector of datasets not found),
`all_ready` (logical).

## See also

[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
to download and cache bulk data,
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
for one-off downloads.

## Examples

``` r
brreg_status()
#> ✔ enheter: available (download cache)
#> ✖ underenheter: not available
#> ✖ roller: not available
#> $available
#> [1] "enheter"
#> 
#> $missing
#> [1] "underenheter" "roller"      
#> 
#> $all_ready
#> [1] FALSE
#> 
```
