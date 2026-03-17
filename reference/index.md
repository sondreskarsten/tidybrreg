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

## Roles and governance

Board members, officers, auditors, and inter-company role relationships.
See
[`vignette("governance")`](https://sondreskarsten.github.io/tidybrreg/articles/governance.md)
for network analysis.

- [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
  : Retrieve board members, officers, and auditors
- [`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md)
  : Retrieve roles an entity holds in other entities
- [`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md)
  : Derive board-level summary covariates from role data
- [`brreg_board_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_network.md)
  : Build a director interlock network
- [`brreg_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_network.md)
  : Build an entity network graph
- [`brreg_survival_data()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_survival_data.md)
  : Prepare firm survival data

## Bulk downloads

Download the full register as CSV or JSON. Three registries: enheter
(~1M entities), underenheter (~950K sub-entities), roller (~5M role
records).

- [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
  : Download the full Norwegian business register
- [`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md)
  : Check availability of local bulk datasets

## Snapshot engine

Save dated bulk downloads as Hive-partitioned Parquet files for panel
construction and historical analysis. See
[`vignette("panels")`](https://sondreskarsten.github.io/tidybrreg/articles/panels.md)
for workflows.

- [`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
  : Save a dated snapshot of the full register
- [`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md)
  : Import a historical CSV as a snapshot partition
- [`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)
  : List available snapshots
- [`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md)
  : Open the snapshot store as a lazy Arrow Dataset
- [`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md)
  : Remove old snapshots from the local store
- [`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md)
  : Path to the tidybrreg snapshot store
- [`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md)
  : Read the snapshot manifest

## Panel construction and time series

Build firm-period panels from snapshots, reconstruct state via CDC
replay, compute aggregate time series, and convert to tsibble for the
tidyverts ecosystem.

- [`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
  : Construct a firm-period panel from accumulated snapshots
- [`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md)
  : Compute daily entry and exit flows
- [`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md)
  : Reconstruct register state by replaying CDC updates
- [`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
  : Detect changes between two snapshots
- [`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)
  : Compute aggregate time series from snapshots
- [`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md)
  : Convert tidybrreg output to tsibble

## Incremental updates (CDC)

Fetch change events from the brreg API’s change data capture stream.
Supports enheter, underenheter, and roller.

- [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
  : Retrieve incremental entity updates

## Labels and translation

Translate Norwegian codes to English descriptions. Follows the eurostat
package’s `type = "label"` pattern.

- [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
  : Translate codes to human-readable English labels
- [`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)
  : Fetch a brreg dictionary

## Harmonization

Remap codes across classification changes (municipality boundary
reforms, NACE reclassifications) using SSB KLASS.

- [`brreg_harmonize_kommune()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_kommune.md)
  : Harmonize municipality codes across boundary reforms
- [`brreg_harmonize_nace()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_nace.md)
  : Harmonize NACE industry codes across classification revisions

## Reference data

Bundled datasets mapping Norwegian codes to English names.

- [`field_dict`](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md)
  : Field dictionary: Norwegian API paths to English column names
- [`legal_forms`](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md)
  : Norwegian legal form codes with English translations
- [`role_types`](https://sondreskarsten.github.io/tidybrreg/reference/role_types.md)
  : Role type codes with English translations
- [`role_groups`](https://sondreskarsten.github.io/tidybrreg/reference/role_groups.md)
  : Role group codes with English translations
