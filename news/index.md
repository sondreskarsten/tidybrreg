# Changelog

## tidybrreg 0.3.2

### Event-sourcing sync engine

- [`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
  — maintains a local mirror of the Enhetsregisteret by applying
  incremental CDC events to persistent parquet state files. On first
  run, bootstraps from bulk download. Subsequent runs poll from the last
  cursor position. Write ordering (changelog → state → cursor) ensures
  crash-safe idempotent replay.
- [`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md)
  — displays state file sizes, cursor positions, last sync time, and
  changelog partition count.
- Four state files maintained: `enheter.parquet`,
  `underenheter.parquet`, `roller.parquet`, `paategninger.parquet`.
- Hive-partitioned changelog under `state/changelog/sync_date=.../` for
  efficient date-range queries via
  [`arrow::open_dataset()`](https://arrow.apache.org/docs/r/reference/open_dataset.html).

### Registry annotations (påtegninger)

- [`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md)
  — query the påtegninger state table by org_nr and/or infotype code.
  Påtegninger are registry-level annotations about entity data quality —
  the earliest formal signal of entity distress, preceding forced
  dissolution by weeks to months.
- [`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md)
  — count entities with active annotations grouped by infotype.
- Påtegninger treated as a conceptually distinct fourth data stream
  alongside enheter, underenheter, and roller.

### Unified change tracking

- [`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
  — query the changelog for field-level mutations across all four
  streams. Filter by track (field names), registry, change_type, date
  range, and org_nr.
- [`brreg_change_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_change_summary.md)
  — count changes by registry, type, field.
- [`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md)
  now auto-detects the changelog when called with no arguments:
  [`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md)
  reads from the sync changelog, `brreg_flows(data)` uses the original
  bulk + CDC path.

## tidybrreg 0.3.1

### New functions

- [`brreg_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_network.md)
  — build entity ego-network graphs as `tbl_graph` objects. Depth 0
  (seed only), depth 1 (sub-units, children, roles, legal roles via
  API), depth 2 (board interlocks via local bulk data). Extensible
  collector pattern for future relationship types.
- [`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md)
  — convenience wrapper to get all sub-units (BEDR/AAFY) belonging to a
  parent entity.
- [`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md)
  — get child enheter in the organisational hierarchy (e.g. Stortinget →
  Riksrevisjonen).
- [`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md)
  — check local bulk data availability for all three registry types.

### Changes

- [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
  now defaults to `registry = "auto"`, trying enheter first then falling
  back to underenheter on 404. Output gains a `registry` column.
  Explicit `registry = "enheter"` or `registry = "underenheter"` skips
  the fallback.
- Bulk data resolution uses Arrow lazy-load for all three types (was
  roller-only). Session cache in `.brregEnv` avoids re-reading parquet
  files across repeated calls. Per-type lazy pipeline in depth-2
  expansion early-exits when no new entities are discovered.

### Infrastructure

- Docker CI matrix simplified to R 4.4.1 only (R 4.3.3 image was never
  built; multi-version coverage via standard R-CMD-check).

## tidybrreg 0.3.0

### Documentation

- pkgdown site with 10 reference groups deployed to GitHub Pages.
- 5 vignettes: Getting started, Norwegian business data, Building firm
  panels, Corporate governance research, Package architecture.
- ARCHITECTURE.md (390 lines) documenting full data flow.
- CONTRIBUTING.md, CODE_OF_CONDUCT.md, GitHub issue templates.
- Hex sticker logo at `man/figures/logo.svg`.
- Lifecycle experimental badge in README.
- r-universe registration for binary installs.
- Install instructions updated: pak (recommended), r-universe, remotes.

### Test coverage

- New test files for
  [`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md),
  [`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md),
  [`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md),
  and
  [`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md).

## tidybrreg 0.2.0

### New features

#### Snapshot engine

- [`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md)
  downloads and saves dated bulk register extracts as Hive-partitioned
  Parquet files. Supports `type = "enheter"`, `"underenheter"`, and
  `"roller"` (via `/roller/totalbestand`). Raw `.gz` files are preserved
  alongside processed Parquet for provenance.
- [`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md)
  adds user-supplied historical CSVs as snapshot partitions, normalizing
  column names via `field_dict`.
- [`brreg_snapshots()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshots.md)
  lists available snapshots with dates, sizes, and paths.
- [`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md)
  opens the partitioned dataset as a lazy Arrow Dataset (requires the
  arrow package).
- [`brreg_data_dir()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_data_dir.md)
  returns the snapshot store path. Override with
  `options(brreg.data_dir = "/custom/path")`.
- [`brreg_cleanup()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_cleanup.md)
  prunes old partitions by count or age.

#### Provenance manifest

- [`brreg_manifest()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_manifest.md)
  reads the JSON provenance catalog recording every download: endpoint
  URL, download timestamp, `Last-Modified` header (data vintage date),
  ETag, file hash, record count, and file paths. Used to bridge
  snapshots to CDC updates without gaps.

#### Panel construction

- [`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)
  constructs firm x period panels at annual, quarterly, monthly, or
  custom cadence from accumulated snapshots. Uses LOCF (last observation
  carried forward) date resolution.
- [`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md)
  reconstructs register state at arbitrary dates from a base snapshot +
  CDC update stream. Applies Ny/Endring/Sletting events chronologically
  via
  [`dplyr::rows_upsert()`](https://dplyr.tidyverse.org/reference/rows.html)
  pattern.
- [`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
  diffs two snapshots: entries, exits, field changes with both old and
  new values.
- [`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)
  computes aggregate time series for any combination of variables
  (`.vars`), summary functions (`.fns`), and grouping columns (`by`).
  Output columns named `{variable}_{function}`.
- [`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md)
  converts panel or series output to tsibble with `regular = FALSE` for
  the tidyverts ecosystem.

#### Entity and sub-entity access

- [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
  and
  [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
  gain `registry = "underenheter"` parameter for sub-entity
  (establishment) lookups and search.
- [`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md)
  performs reverse role lookup: what roles does entity X hold in other
  entities (parent, shareholder, partner).

#### Bulk downloads

- [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
  supports `type = "roller"` via `/roller/totalbestand` (131 MB gzipped
  JSON).
- `brreg_download(format = "json")` downloads the full JSON bulk for
  enheter/underenheter via `/enheter/lastned`.
- Algorithmic JSON unnesting flattens all list columns to atomic types
  (character vectors collapsed, data frames serialized, HAL links
  dropped). Shared
  [`rename_and_coerce()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_and_coerce.md)
  pipeline for both CSV and JSON paths.

#### Concordance

- [`brreg_harmonize_kommune()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_kommune.md)
  remaps municipality codes across Norway’s 2020 municipal reform and
  2024 county reversals using SSB KLASS.
- [`brreg_harmonize_nace()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_nace.md)
  remaps NACE SN2007 to SN2025 via SSB KLASS.

#### Governance research

- [`brreg_board_network()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_network.md)
  builds director interlock networks as `tbl_graph` objects (requires
  tidygraph).
- [`brreg_survival_data()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_survival_data.md)
  prepares firm survival data with time-to-event and right-censoring
  indicators compatible with
  [`survival::Surv()`](https://rdrr.io/pkg/survival/man/Surv.html).

#### CDC updates

- `brreg_updates(type = "roller")` fetches role change events in
  CloudEvents format (different schema from enheter/underenheter).

### Dependency changes

- Added jsonlite to Imports (roller bulk JSON parsing).
- Added nanoparquet (\>= 0.3.0), tsibble to Suggests.
- Removed igraph, plm, fixest, collapse, sf, ggraph from Suggests.

## tidybrreg 0.1.0

- Initial release.
- Entity lookup
  ([`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)),
  filtered search
  ([`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)),
  board/officer roles
  ([`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
  [`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md)).
- Full register bulk download
  ([`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)).
- Incremental CDC updates
  ([`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)).
- Code-to-label translation
  ([`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md),
  [`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)).
- Organization number validation
  ([`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md)).
- Reference datasets: `field_dict`, `legal_forms`, `role_types`,
  `role_groups`.
