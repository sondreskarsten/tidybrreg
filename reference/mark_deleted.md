# Flag deletion on an entity row

Reads the two signals BRREG uses for a deleted entity (HTTP 410, or
`respons_klasse == "SlettetEnhet"` on a 200) and sets `deleted` and
`deletion_date` consistently.

## Usage

``` r
mark_deleted(result, status, body)
```
