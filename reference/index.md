# Package index

## Entity lookup

Retrieve details for specific entities by organization number. See
[`vignette("tidybrreg")`](https://sondreskarsten.github.io/tidybrreg/articles/tidybrreg.md)
for a complete walkthrough.

- [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
  : Look up a Norwegian legal entity
- [`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md)
  : Get all sub-units (underenheter) belonging to an entity
- [`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md)
  : Get child entities in the organisational hierarchy
- [`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md)
  : Validate Norwegian organization numbers

## Search

Query the register by name, legal form, industry, geography, and other
criteria. Supports both main entities and sub-entities.

- [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
  : Search Norwegian legal entities

## Roles, groups and signing authority

Board members, officers, auditors, reverse role lookups, the corporate
group tree, and signature and procuration authority.

- [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
  : Retrieve board members, officers, and auditors
- [`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md)
  : Retrieve roles an entity holds in other entities
- [`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md)
  : Retrieve the corporate group structure (konsernstruktur)
- [`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md)
  : Retrieve signature authority (signaturrett)
- [`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md)
  : Retrieve procuration authority (prokura)

## Annual accounts

Key figures of the annual accounts filed with Regnskapsregisteret, one
row per filing.

- [`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md)
  : Retrieve annual accounts (regnskap) from Regnskapsregisteret

## Incremental updates (CDC)

Fetch change events from the brreg API’s change data capture streams for
enheter, underenheter, and roller.

- [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
  : Retrieve incremental entity updates
- [`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md)
  : Retrieve field-level CDC changes as a flat tibble

## Bulk download

Download the full register as CSV or JSON. Three registries: enheter,
underenheter, roller.

- [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
  : Download the full Norwegian business register

## Labels and dictionaries

Translate Norwegian codes to English or Norwegian descriptions. Follows
the eurostat package’s `type = "label"` pattern.

- [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
  : Translate codes to human-readable labels
- [`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)
  : Fetch a brreg dictionary

## Reference data and conditions

Bundled datasets, their provenance, and the condition classes the
package signals.

- [`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
  : Field dictionary: Norwegian API paths to English column names
- [`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md)
  : Norwegian legal form codes with English translations
- [`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
  : Role type codes with English translations
- [`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
  : Role group codes with English translations
- [`regnskap_dict`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md)
  : Regnskap field dictionary: filing JSON paths to English column names
- [`regnskap_groups`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)
  : Regnskap groups: the objects that group line items, with labels
- [`regnskap_items`](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md)
  : Regnskap line items with English and Norwegian labels
- [`tidybrreg_provenance`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_provenance.md)
  : Provenance of the bundled reference data
- [`tidybrreg_conditions`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md)
  : Conditions signalled by tidybrreg
- [`tidybrreg_endpoints`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_endpoints.md)
  : Retrieval limits of the register endpoints
