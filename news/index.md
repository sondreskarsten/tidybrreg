# Changelog

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
