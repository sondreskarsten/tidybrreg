# Changelog

## tidybrreg 0.3.8

### Bug fixes

- [`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md)
  now populates `paategninger` state. The enheter bulk download (CSV)
  only carries påtegninger as a boolean presence flag, not the
  annotation content, so
  [`extract_paategninger()`](https://sondreskarsten.github.io/tidybrreg/reference/extract_paategninger.md)
  previously always produced empty state and
  [`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md)
  returned nothing after a sync. The bootstrap now reads the flag
  (column `annotations`) and fetches the actual annotation content per
  flagged entity from the enheter endpoint. New internal helper
  [`fetch_entity_paategninger()`](https://sondreskarsten.github.io/tidybrreg/reference/fetch_entity_paategninger.md).

## tidybrreg 0.3.7

### New features

- New bundled dataset \[annotation_infotypes\]: maps brreg påtegning
  `infotype` codes to English descriptions. Sourced from the brreg API
  reference (`NAVN`, `FADR`) and codes observed in live data (role codes
  used for missing-role annotations); unknown codes pass through.
- [`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md)
  gains a `translate` argument. With `translate = TRUE` an
  `infotype_desc` column with English descriptions (from
  `annotation_infotypes`) is added after `infotype`. Default `FALSE`, so
  existing behaviour is unchanged.

### Documentation

- `field_dict` documentation now lists `numeric` among the coercion
  types (added in 0.3.6 for `capital_shares`).

## tidybrreg 0.3.6

### Bug fixes

- `field_dict`: `capital_shares` (`kapital.antallAksjer`) is now typed
  `numeric` instead of `integer`. The share count exceeds the 32-bit
  integer range for large-cap entities (e.g. Equinor ASA, 2,556,807,512
  shares), so
  [`coerce_types()`](https://sondreskarsten.github.io/tidybrreg/reference/coerce_types.md)
  silently produced `NA` with an “NAs introduced by coercion to integer
  range” warning. It now retains the value, consistent with the other
  `kapital.*` fields.
- Bundled `role_types` and `role_groups`: Norwegian role names
  (`Observatør`, `Regnskapsfører`, `Forretningsfører`, `FFØR`,
  `Helse, miljø og sikkerhet`) are now stored as UTF-8 escapes in
  `data-raw/build_dictionaries.R` and saved with UTF-8 encoding marking.
  String values are byte-identical to before; this only clears the R CMD
  check “non-ASCII strings” data warning.

### Internal

- [`read_changelog()`](https://sondreskarsten.github.io/tidybrreg/reference/read_changelog.md):
  the arrow branch now references the partition column as
  `.data$sync_date` and imports the
  [`rlang::.env`](https://rlang.r-lib.org/reference/dot-data.html)
  pronoun, removing the “no visible binding for global variable” check
  note. Runtime behaviour is unchanged.
- Tests: `field_dict` invariants aligned with the v0.3.5 dictionary —
  `api_path` is the unique key (multiple API-spelling variants map to a
  single `col_name`), and `numeric` is an accepted type.

## tidybrreg 0.3.4

### Roller CDC: field-level change detection

- [`bootstrap_state()`](https://sondreskarsten.github.io/tidybrreg/reference/bootstrap_state.md)
  now initializes the CDC cursor to the current tip (max event ID) at
  bootstrap time via
  [`get_cdc_tip()`](https://sondreskarsten.github.io/tidybrreg/reference/get_cdc_tip.md).
  Previously the cursor remained at 0 after bootstrap, causing the first
  CDC poll to replay the entire event history (~4.4M roller events, ~24M
  enheter events). This caused OOM and timeout failures on Cloud Run.
- `bootstrap_state(roller_method = "cdc")` skips the roller totalbestand
  download entirely. Writes an empty state table and builds state
  incrementally via per-org
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
  calls. Reduces bootstrap from 32 GiB RAM / 30+ minutes to \<10 seconds
  and negligible memory.
- [`paginate_cdc()`](https://sondreskarsten.github.io/tidybrreg/reference/paginate_cdc.md)
  gains a `max_pages` parameter and a safety guard: if `cursor_id == 0`
  (no prior sync), pagination caps at 5 pages and emits a
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html).
  Belt-and-suspenders — should never trigger after a correct bootstrap.
- [`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md)
  (new, exported) — computes field-level diffs between two flattened
  roller state tibbles. Returns a long-format changelog with
  `change_type` (entry/exit/change), `field`, `value_from`, `value_to`.
  Roles are keyed by a composite of
  `(org_nr, role_group_code, role_code, holder_id)` where holder_id is
  derived from `person_id` (person-held) or `entity:{org_nr}`
  (entity-held).
- `brreg_sync(roller_method = "bulk")` — new default strategy for
  roller CDC. Downloads the full totalbestand (~131 MB), diffs against
  stored state, and writes a field-level changelog. Replaces the per-org
  API pattern for full-register syncs.
- `brreg_sync(roller_method = "cdc")` — per-org API fallback for
  sub-daily syncs. Fetches current roles via
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md)
  for each CDC event, diffs per-org. Slower but provides per-event
  timestamp attribution.
- [`flatten_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles.md)
  gains 4 new columns: `deregistered` (avregistrert), `ordering`
  (rekkefolge), `elected_by` (valgtAv\$kode), `group_modified`
  (sistEndret as Date).
- [`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md)
  now excludes resigned and deregistered roles from all counts and gains
  `n_employee_elected` (count of board members with a non-NA
  `elected_by` value).

### Performance

- [`flatten_roles_bulk_fast()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles_bulk_fast.md)
  (internal) — vectorized two-pass flatten for bulk totalbestand.
  Pre-allocates vectors and fills by index. 4.1× faster than the
  per-entity
  [`flatten_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_roles.md)
  path (4,192 vs 1,028 roles/sec).
- [`read_roles_json()`](https://sondreskarsten.github.io/tidybrreg/reference/read_roles_json.md)
  (internal) — dispatches to yyjsonr when available (10× parse speed,
  70× lower memory vs jsonlite). yyjsonr added to Suggests.
- [`lookup_role_vec()`](https://sondreskarsten.github.io/tidybrreg/reference/lookup_role_vec.md)
  and
  [`lookup_role_group_vec()`](https://sondreskarsten.github.io/tidybrreg/reference/lookup_role_group_vec.md)
  (internal) — vectorized code-to-label lookups replacing per-row
  [`match()`](https://rdrr.io/r/base/match.html).

### Bug fixes

- [`extract_entity_name()`](https://sondreskarsten.github.io/tidybrreg/reference/extract_entity_name.md)
  no longer returns NA for entity-held roles. The brreg API returns
  `enhet.navn` as a JSON array `["ERNST & YOUNG AS"]`, not a named
  object. jsonlite parses this as an unnamed list, which the old code
  did not handle. Added unnamed list branch.
- [`read_roles_json()`](https://sondreskarsten.github.io/tidybrreg/reference/read_roles_json.md)
  now decompresses `.gz` files to a temp file before passing to yyjsonr.
  yyjsonr cannot read gzipped files directly; the previous code crashed
  with a buffer allocation error on the 131 MB totalbestand.
- [`paginate_cdc_bounded()`](https://sondreskarsten.github.io/tidybrreg/reference/paginate_cdc_bounded.md)
  (internal) caps roller CDC pagination at 5 pages (50K events) when
  using `roller_method = "bulk"`. The previous unbounded
  [`paginate_cdc()`](https://sondreskarsten.github.io/tidybrreg/reference/paginate_cdc.md)
  fetched the entire CDC history (1.1M+ events) from cursor 0 on first
  bootstrap, causing 30-minute timeouts.
- [`parse_sync_page()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_sync_page.md)
  no longer produces tibble column size mismatches when CDC pages
  contain events without `endringer` (Ny/Sletting).
  `raw_changes[[i]] <- NULL` was deleting list elements instead of
  preserving NULL placeholders (R double-bracket assignment semantics).
  Fix: [`list()`](https://rdrr.io/r/base/list.html) as empty
  placeholder. Affected all enheter and underenheter sync since v0.3.2.
- [`add_role_key()`](https://sondreskarsten.github.io/tidybrreg/reference/add_role_key.md)
  no longer crashes on 0-row tibbles. Previously,
  `case_when(df$person_id ...)` received NULL instead of NA when passed
  a 0-column tibble from a 404 API response.
- [`apply_roller_events_cdc()`](https://sondreskarsten.github.io/tidybrreg/reference/apply_roller_events_cdc.md)
  skips
  [`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md)
  when both old and new state are empty (entity not in state AND 404
  from API).

## tidybrreg 0.3.3

### Bug fixes

- [`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md)
  no longer silently drops Ny, Sletting, and Fjernet CDC events. Events
  with no `endringer` array now emit a synthetic row with
  `operation = NA`, `field = NA`, `new_value = NA`, preserving event
  metadata for downstream filtering and counting. Previously, filtering
  [`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md)
  output for `change_type == "Ny"` returned zero rows.
- [`flatten_page_patches()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_page_patches.md)
  and
  [`parse_patch()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_patch.md)
  now handle RFC 6902 `move` operations correctly: the value is written
  to the destination path and a synthetic `remove` row is emitted for
  the source path (from `$from`). `copy` operations already worked but
  now follow the same explicit dispatch path.
- Stale roxygen docstring for
  [`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md)
  removed references to RcppSimdJson and parallel processing (both
  removed in 0.3.2). Documentation now accurately describes the
  sequential fetch-and-flatten loop and the synthetic row behaviour for
  Ny/ Sletting/Fjernet events.

### Field dictionary

- `field_dict` grows from 62 to 70 rows. New entries:
  - `fravalgRevisjonDato` → `audit_exemption_date` (Date)
  - `fravalgRevisjonBeslutningsDato` → `audit_exemption_decision_date`
    (Date)
  - `registreringsdatoMerverdiavgiftsregisteretEnhetsregisteret` →
    `vat_registration_date_er` (Date)
  - `registreringsdatoAntallAnsatteEnhetsregisteret` →
    `employee_reg_date_er` (Date)
  - `registreringsdatoAntallAnsatteNavAaregisteret` →
    `employee_reg_date_nav` (Date)
  - `oppstartsdato` → `start_date` (Date) — underenhet operations start
    date
  - `registrertIPartiregisteret` → `in_party_register` (logical)
  - `respons_klasse` → `response_class` (character) — API response
    metadata class

### Sync engine

- [`find_state_column()`](https://sondreskarsten.github.io/tidybrreg/reference/find_state_column.md)
  gains mappings for all 8 new field_dict entries. CDC field changes for
  audit exemption dates, employee registration dates, VAT registration
  date in Enhetsregisteret, underenhet start dates, and party register
  membership are no longer silently skipped during
  [`brreg_sync()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync.md).

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
