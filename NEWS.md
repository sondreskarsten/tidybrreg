# tidybrreg 0.2.0

## New features

### Snapshot engine
* `brreg_snapshot()` downloads and saves dated bulk register extracts as
  Hive-partitioned Parquet files in `tools::R_user_dir("tidybrreg", "data")`.
* `brreg_import()` adds user-supplied historical CSVs as snapshot partitions,
  normalizing column names via `field_dict`.
* `brreg_snapshots()` lists available snapshots with dates, sizes, and paths.
* `brreg_open()` opens the partitioned dataset as a lazy Arrow Dataset
  (requires the arrow package).
* `brreg_data_dir()` returns the snapshot store path.
  Override with `options(brreg.data_dir = "/custom/path")`.
* `brreg_cleanup()` prunes old partitions by count or age.

### Panel construction
* `brreg_panel()` constructs firm x period panels at annual, quarterly,
  monthly, or custom cadence from accumulated snapshots. Uses LOCF (last
  observation carried forward) date resolution.
* `brreg_events()` diffs two snapshots and returns entries, exits, and
  field-level changes with both old and new values.
* `brreg_series()` computes aggregate time series (entity counts, total
  employees, entry/exit flows) with optional grouping by NACE code,
  legal form, or municipality.

### Concordance
* `brreg_harmonize_kommune()` remaps municipality codes across Norway's
  2020 municipal reform and 2024 county reversals using SSB KLASS
  correspondence tables (requires klassR).
* `brreg_harmonize_nace()` remaps NACE industry codes between SN2007
  and SN2025 revisions, flagging ambiguous one-to-many mappings.

### Governance research
* `brreg_board_network()` builds director interlock networks as
  `tbl_graph` objects (requires tidygraph) for centrality analysis
  and ggraph visualization.
* `brreg_survival_data()` prepares firm survival data with time-to-event
  and right-censoring indicators compatible with `survival::Surv()`.

## Dependency changes
* Added nanoparquet (>= 0.3.0) to Suggests as lightweight Parquet
  fallback when arrow is not installed.
* Added duckdb and tidyr to Suggests.
* Removed igraph, plm, fixest, collapse, sf, ggraph from Suggests
  (user-side downstream packages, not used internally).

## Minor improvements
* `brreg_data_dir()` respects `options(brreg.data_dir =)` for test
  redirection and custom storage locations.
* `@importFrom rlang .data` added for CRAN compliance with tidy
  evaluation in dplyr pipelines.

# tidybrreg 0.1.0

* Initial release.
* Entity lookup (`brreg_entity()`), filtered search (`brreg_search()`),
  board/officer roles (`brreg_roles()`, `brreg_board_summary()`).
* Full register bulk download (`brreg_download()`).
* Incremental CDC updates (`brreg_updates()`).
* Code-to-label translation (`brreg_label()`, `get_brreg_dic()`)
  following the eurostat package's `label_eurostat()` pattern.
* Organization number validation (`brreg_validate()`).
* Reference datasets: `field_dict`, `legal_forms`, `role_types`,
  `role_groups`.
