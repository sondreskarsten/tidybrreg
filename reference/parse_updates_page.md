# Parse a page of raw CDC update objects into a tibble

Parse a page of raw CDC update objects into a tibble

## Usage

``` r
parse_updates_page(raw_updates, include_changes = FALSE)
```

## Arguments

- raw_updates:

  List of update objects from the API.

- include_changes:

  Logical. Parse and attach field changes.
