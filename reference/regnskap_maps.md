# Maps of the Regnskapsregisteret filing shape

The bundled datasets
[regnskap_dict](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md),
[regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)
and
[regnskap_items](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md)
describe the filing JSON (OpenAPI 1.1.16) the way
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md),
[role_groups](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
and
[role_types](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
describe entities and roles: `regnskap_dict` is applied by
[`rename_from_dict()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_from_dict.md)
and
[`coerce_types()`](https://sondreskarsten.github.io/tidybrreg/reference/coerce_types.md)
and names the line items, `regnskap_groups` names the objects that group
line items (its level-0 rows are the three statements,
[`regnskap_statements()`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_statements.md)),
and `regnskap_items` carries the English and Norwegian labels
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
applies. `regnskap_identities` lists the accounting identities checked
per filing on the line items (by item name; `optional` terms count as 0
when absent) within `regnskap_tolerance`. All of this is published under
`brreg_regnskap` in `inst/extdata/endpoints.json` and held equal to
these objects by `tests/testthat/test-endpoints.R`.
