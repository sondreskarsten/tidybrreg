# tidybrreg 0.1.0

* Initial release.

## New features
* `brreg_entity()` looks up a single entity by organization number.
* `brreg_search()` queries entities by name, legal form, industry,
  municipality, employee count, and bankruptcy status.
* `brreg_roles()` retrieves board members, officers, and auditors.
* `brreg_board_summary()` derives board-level covariates from role data.
* `brreg_updates()` accesses the change data capture (CDC) endpoint
  with optional field-level change details.
* `brreg_label()` translates coded values to English descriptions
  using bundled reference data or live SSB Klass API lookups.
* `brreg_validate()` validates organization numbers via modulus-11.

## Architecture
* Data-driven column dictionary (`field_dict`) maps Norwegian API
  field names to English. Unknown API fields pass through with
  auto-generated snake_case names rather than being silently dropped.
* Bundled reference data: 44 legal forms, 18 role types, 15 role
  groups, 1783 NACE codes (English from SSB Klass), 33 institutional
  sector codes.
* All reference data regenerated from live APIs via
  `data-raw/build_dictionaries.R`.
