# Flatten a single brreg entity JSON to a 1-row tibble

Uses the field_dict column dictionary. Fields present in the API
response but absent from field_dict pass through with auto-generated
snake_case names. Fields in field_dict but absent from the response are
omitted rather than materialized as NA: a column the register did not
emit is not asserted. Multi-entity callers bind the per-entity tibbles,
so a column appears whenever any entity in the batch carried it, NA for
the rest.

## Usage

``` r
parse_entity(raw)
```
