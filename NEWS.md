# tidybrreg 0.3.4

## Roller CDC: field-level change detection

* `diff_roller_state()` (new, exported) — computes field-level diffs
  between two flattened roller state tibbles. Returns a long-format
  changelog with `change_type` (entry/exit/change), `field`,
  `value_from`, `value_to`. Roles are keyed by a composite of
  `(org_nr, role_group_code, role_code, holder_id)` where holder_id
  is derived from `person_id` (person-held) or
  `entity:{org_nr}` (entity-held).
* `brreg_sync(roller_method = "bulk")` — new default strategy for
  roller CDC. Downloads the full totalbestand (~131 MB), diffs against
  stored state, and writes a field-level changelog. Replaces the
  per-org API pattern for full-register syncs.
* `brreg_sync(roller_method = "cdc")` — per-org API fallback for
  sub-daily syncs. Fetches current roles via `brreg_roles()` for each
  CDC event, diffs per-org. Slower but provides per-event timestamp
  attribution.
* `flatten_roles()` gains 4 new columns: `deregistered` (avregistrert),
  `ordering` (rekkefolge), `elected_by` (valgtAv$kode),
  `group_modified` (sistEndret as Date).
* `brreg_board_summary()` now excludes resigned and deregistered roles
  from all counts and gains `n_employee_elected` (count of board
  members with a non-NA `elected_by` value).

## Performance

* `flatten_roles_bulk_fast()` (internal) — vectorized two-pass
  flatten for bulk totalbestand. Pre-allocates vectors and fills by
  index. 4.1× faster than the per-entity `flatten_roles()` path
  (4,192 vs 1,028 roles/sec).
* `read_roles_json()` (internal) — dispatches to yyjsonr when
  available (10× parse speed, 70× lower memory vs jsonlite).
  yyjsonr added to Suggests.
* `lookup_role_vec()` and `lookup_role_group_vec()` (internal) —
  vectorized code-to-label lookups replacing per-row `match()`.

## Bug fixes

* `extract_entity_name()` no longer returns NA for entity-held roles.
  The brreg API returns `enhet.navn` as a JSON array `["ERNST & YOUNG
  AS"]`, not a named object. jsonlite parses this as an unnamed list,
  which the old code did not handle. Added unnamed list branch.
* `read_roles_json()` now decompresses `.gz` files to a temp file
  before passing to yyjsonr. yyjsonr cannot read gzipped files
  directly; the previous code crashed with a buffer allocation error
  on the 131 MB totalbestand.
* `paginate_cdc_bounded()` (internal) caps roller CDC pagination at
  5 pages (50K events) when using `roller_method = "bulk"`. The
  previous unbounded `paginate_cdc()` fetched the entire CDC history
  (1.1M+ events) from cursor 0 on first bootstrap, causing 30-minute
  timeouts.
* `parse_sync_page()` no longer produces tibble column size mismatches
  when CDC pages contain events without `endringer` (Ny/Sletting).
  `raw_changes[[i]] <- NULL` was deleting list elements instead of
  preserving NULL placeholders (R double-bracket assignment semantics).
  Fix: `list()` as empty placeholder. Affected all enheter and
  underenheter sync since v0.3.2.
* `add_role_key()` no longer crashes on 0-row tibbles. Previously,
  `case_when(df$person_id ...)` received NULL instead of NA when
  passed a 0-column tibble from a 404 API response.
* `apply_roller_events_cdc()` skips `diff_roller_state()` when both
  old and new state are empty (entity not in state AND 404 from API).

# tidybrreg 0.3.3

## Bug fixes

* `brreg_update_fields()` no longer silently drops Ny, Sletting, and
  Fjernet CDC events. Events with no `endringer` array now emit a
  synthetic row with `operation = NA`, `field = NA`, `new_value = NA`,
  preserving event metadata for downstream filtering and counting.
  Previously, filtering `brreg_update_fields()` output for
  `change_type == "Ny"` returned zero rows.
* `flatten_page_patches()` and `parse_patch()` now handle RFC 6902
  `move` operations correctly: the value is written to the destination
  path and a synthetic `remove` row is emitted for the source path
  (from `$from`). `copy` operations already worked but now follow the
  same explicit dispatch path.
* Stale roxygen docstring for `brreg_update_fields()` removed
  references to RcppSimdJson and parallel processing (both removed
  in 0.3.2). Documentation now accurately describes the sequential
  fetch-and-flatten loop and the synthetic row behaviour for Ny/
  Sletting/Fjernet events.

## Field dictionary

* `field_dict` grows from 62 to 70 rows. New entries:
  - `fravalgRevisjonDato` → `audit_exemption_date` (Date)
  - `fravalgRevisjonBeslutningsDato` → `audit_exemption_decision_date` (Date)
  - `registreringsdatoMerverdiavgiftsregisteretEnhetsregisteret` →
    `vat_registration_date_er` (Date)
  - `registreringsdatoAntallAnsatteEnhetsregisteret` →
    `employee_reg_date_er` (Date)
  - `registreringsdatoAntallAnsatteNavAaregisteret` →
    `employee_reg_date_nav` (Date)
  - `oppstartsdato` → `start_date` (Date) — underenhet operations
    start date
  - `registrertIPartiregisteret` → `in_party_register` (logical)
  - `respons_klasse` → `response_class` (character) — API response
    metadata class

## Sync engine

* `find_state_column()` gains mappings for all 8 new field_dict
  entries. CDC field changes for audit exemption dates, employee
  registration dates, VAT registration date in Enhetsregisteret,
  underenhet start dates, and party register membership are no longer
  silently skipped during `brreg_sync()`.

# tidybrreg 0.3.2

## Event-sourcing sync engine

* `brreg_sync()` — maintains a local mirror of the Enhetsregisteret
  by applying incremental CDC events to persistent parquet state
  files. On first run, bootstraps from bulk download. Subsequent
  runs poll from the last cursor position. Write ordering
  (changelog → state → cursor) ensures crash-safe idempotent replay.
* `brreg_sync_status()` — displays state file sizes, cursor
  positions, last sync time, and changelog partition count.
* Four state files maintained: `enheter.parquet`,
  `underenheter.parquet`, `roller.parquet`, `paategninger.parquet`.
* Hive-partitioned changelog under `state/changelog/sync_date=.../`
  for efficient date-range queries via `arrow::open_dataset()`.

## Registry annotations (påtegninger)

* `brreg_annotations()` — query the påtegninger state table by
  org_nr and/or infotype code. Påtegninger are registry-level
  annotations about entity data quality — the earliest formal
  signal of entity distress, preceding forced dissolution by
  weeks to months.
* `brreg_annotation_summary()` — count entities with active
  annotations grouped by infotype.
* Påtegninger treated as a conceptually distinct fourth data
  stream alongside enheter, underenheter, and roller.

## Unified change tracking

* `brreg_changes()` — query the changelog for field-level mutations
  across all four streams. Filter by track (field names), registry,
  change_type, date range, and org_nr.
* `brreg_change_summary()` — count changes by registry, type, field.
* `brreg_flows()` now auto-detects the changelog when called with
  no arguments: `brreg_flows()` reads from the sync changelog,
  `brreg_flows(data)` uses the original bulk + CDC path.

# tidybrreg 0.3.1

## New functions

* `brreg_network()` — build entity ego-network graphs as `tbl_graph`
  objects. Depth 0 (seed only), depth 1 (sub-units, children, roles,
  legal roles via API), depth 2 (board interlocks via local bulk data).
  Extensible collector pattern for future relationship types.
* `brreg_underenheter()` — convenience wrapper to get all sub-units
  (BEDR/AAFY) belonging to a parent entity.
* `brreg_children()` — get child enheter in the organisational
  hierarchy (e.g. Stortinget → Riksrevisjonen).
* `brreg_status()` — check local bulk data availability for all
  three registry types.

## Changes

* `brreg_entity()` now defaults to `registry = "auto"`, trying
  enheter first then falling back to underenheter on 404. Output
  gains a `registry` column. Explicit `registry = "enheter"` or
  `registry = "underenheter"` skips the fallback.
* Bulk data resolution uses Arrow lazy-load for all three types
  (was roller-only). Session cache in `.brregEnv` avoids re-reading
  parquet files across repeated calls. Per-type lazy pipeline in
  depth-2 expansion early-exits when no new entities are discovered.

## Infrastructure

* Docker CI matrix simplified to R 4.4.1 only (R 4.3.3 image was
  never built; multi-version coverage via standard R-CMD-check).

# tidybrreg 0.3.0

## Documentation

* pkgdown site with 10 reference groups deployed to GitHub Pages.
* 5 vignettes: Getting started, Norwegian business data, Building
  firm panels, Corporate governance research, Package architecture.
* ARCHITECTURE.md (390 lines) documenting full data flow.
* CONTRIBUTING.md, CODE_OF_CONDUCT.md, GitHub issue templates.
* Hex sticker logo at `man/figures/logo.svg`.
* Lifecycle experimental badge in README.
* r-universe registration for binary installs.
* Install instructions updated: pak (recommended), r-universe, remotes.

## Test coverage

* New test files for `brreg_manifest()`, `brreg_replay()`,
  `brreg_series()`, and `as_brreg_tsibble()`.

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
