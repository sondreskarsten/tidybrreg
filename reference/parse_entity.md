# Flatten a single brreg entity JSON to a 1-row tibble

Uses the field_dict column dictionary. Fields present in the API
response but absent from field_dict pass through with auto-generated
snake_case names. Fields in field_dict but absent from the response
become NA with correct type.

## Usage

``` r
parse_entity(raw)
```
