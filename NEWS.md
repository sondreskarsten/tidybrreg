# tidybrreg 0.2.0

## New features

### Snapshot engine
* `brreg_snapshot()` downloads and saves dated bulk register extracts as
  Hive-partitioned Parquet files. Supports `type = "enheter"`,
  `"underenheter"`, and `"roller"` (via `/roller/totalbestand`).
  Raw `.gz` files are preserved alongside processed Parquet for provenance.
* `brreg_import()` adds user-supplied historical CSVs as snapshot partitions,
  normalizing column names via `field_dict`.
* `brreg_snapshots()` lists available snapshots with dates, sizes, and paths.
* `brreg_open()` opens the partitioned dataset as a lazy Arrow Dataset
  (requires the arrow package).
* `brreg_data_dir()` returns the snapshot store path.
  Override with `options(brreg.data_dir = "/custom/path")`.
* `brreg_cleanup()` prunes old partitions by count or age.

### Provenance manifest
* `brreg_manifest()` reads the JSON provenance catalog recording every
  download: endpoint URL, download timestamp, `Last-Modified` header
  (data vintage date), ETag, file hash, record count, and file paths.
  Used to bridge snapshots to CDC updates without gaps.

### Panel construction
* `brreg_panel()` constructs firm x period panels at annual, quarterly,
  monthly, or custom cadence from accumulated snapshots. Uses LOCF (last
  observation carried forward) date resolution.
* `brreg_replay()` reconstructs register state at arbitrary dates from
  a base snapshot + CDC update stream. Applies Ny/Endring/Sletting events
  chronologically via `dplyr::rows_upsert()` pattern.
* `brreg_events()` diffs two snapshots: entries, exits, field changes
  with both old and new values.
* `brreg_series()` computes aggregate time series for any combination of
  variables (`.vars`), summary functions (`.fns`), and grouping columns
  (`by`). Output columns named `{variable}_{function}`.
* `as_brreg_tsibble()` converts panel or series output to tsibble
  with `regular = FALSE` for the tidyverts ecosystem.

### Entity and sub-entity access
* `brreg_entity()` and `brreg_search()` gain `registry = "underenheter"`
  parameter for sub-entity (establishment) lookups and search.
* `brreg_roles_legal()` performs reverse role lookup: what roles does
  entity X hold in other entities (parent, shareholder, partner).

### Bulk downloads
* `brreg_download()` supports `type = "roller"` via
  `/roller/totalbestand` (131 MB gzipped JSON).
* `brreg_download(format = "json")` downloads the full JSON bulk
  for enheter/underenheter via `/enheter/lastned`.
* Algorithmic JSON unnesting flattens all list columns to atomic types
  (character vectors collapsed, data frames serialized, HAL links dropped).
  Shared `rename_and_coerce()` pipeline for both CSV and JSON paths.

### Concordance
* `brreg_harmonize_kommune()` remaps municipality codes across Norway's
  2020 municipal reform and 2024 county reversals using SSB KLASS.
* `brreg_harmonize_nace()` remaps NACE SN2007 to SN2025 via SSB KLASS.

### Governance research
* `brreg_board_network()` builds director interlock networks as
  `tbl_graph` objects (requires tidygraph).
* `brreg_survival_data()` prepares firm survival data with time-to-event
  and right-censoring indicators compatible with `survival::Surv()`.

### CDC updates
* `brreg_updates(type = "roller")` fetches role change events in
  CloudEvents format (different schema from enheter/underenheter).

## Dependency changes
* Added jsonlite to Imports (roller bulk JSON parsing).
* Added nanoparquet (>= 0.3.0), tsibble to Suggests.
* Removed igraph, plm, fixest, collapse, sf, ggraph from Suggests.

# tidybrreg 0.1.0

* Initial release.
* Entity lookup (`brreg_entity()`), filtered search (`brreg_search()`),
  board/officer roles (`brreg_roles()`, `brreg_board_summary()`).
* Full register bulk download (`brreg_download()`).
* Incremental CDC updates (`brreg_updates()`).
* Code-to-label translation (`brreg_label()`, `get_brreg_dic()`).
* Organization number validation (`brreg_validate()`).
* Reference datasets: `field_dict`, `legal_forms`, `role_types`,
  `role_groups`.
