# Map a CDC patch field path to a column name

Patch fields use camelCase slash-separated paths (e.g.
`forretningsadresse/postnummer`). This maps them to the field_dict
col_name or auto snake_case.

## Usage

``` r
lookup_patch_field(field, valid_cols)
```
