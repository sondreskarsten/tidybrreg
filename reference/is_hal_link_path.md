# Is a dot-notation path part of a HAL `_links` block?

HAL hypermedia links (`_links.self.href`,
`organisasjonsform._links.self.href`, or `links` after
`jsonlite::fromJSON(flatten = TRUE)` strips the underscore) describe API
navigation, not the entity, and are removed wherever they occur in the
path, not only at the top level.

## Usage

``` r
is_hal_link_path(path)
```

## Arguments

- path:

  Character vector of dot-notation paths.

## Value

Logical vector.
