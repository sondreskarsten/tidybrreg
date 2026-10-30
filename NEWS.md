# tidybrreg 0.6.0

## The split

tidybrreg is now the narrow, typed client to the register: exactly
sixteen exports, each wrapping one endpoint of Enhetsregisteret, the
Fullmakt service, Regnskapsregisteret, or SSB KLASS.

```r
brreg_entity()  brreg_search()  brreg_underenheter()  brreg_children()
brreg_roles()   brreg_roles_legal()  brreg_konsern()
brreg_signatur()  brreg_prokura()
brreg_regnskap()
brreg_updates()  brreg_update_fields()
brreg_download()
brreg_label()  get_brreg_dic()  brreg_validate()
```

The managed-state subsystem (snapshot store, `brreg_sync()`, replay,
changelog queries, flows, panels, series, tsibble conversion, events,
annotations, name history, harmonisation, director networks, survival
data, `brreg_board_summary()`, `diff_roller_state()`, `brreg_status()`)
has moved, unchanged in behaviour, to the companion package
**tidybrregpanel** in the `tidybrregpanel/` directory of this
repository. It depends on tidybrreg and is built alongside it on
r-universe. The pre-split implementation remains at commit `c9bd992`.

The Model Context Protocol server **tidybrregmcp** (`tidybrregmcp/`)
exposes the sixteen exports as MCP tools, deriving every tool's
documentation and schema from this package's help pages, and writes a
manifest (`mcp_manifest()`) from which **tidybrreg-mcp**
(`tidybrreg-mcp-node/`, on npm) serves the same catalogue without R.
The package ships `inst/extdata/endpoints.json`, a machine-readable
contract of every export's endpoint, query mapping and status handling,
held to the functions by `tests/testthat/test-endpoints.R`.

## New: annual accounts

* New `brreg_regnskap()` retrieves an entity's annual accounts from the
  Regnskapsregisteret open API (`GET /regnskapsregisteret/regnskap/{orgnr}`,
  optional `year` and `account_type`). The result is nested: one row per
  filing with its identity, period, currency, legal form and audit
  flags as scalar columns, and the figures as an `items` tibble per
  filing that keeps the API's structure (`statement`, `group`, `item`,
  `path`, `level`, `is_sum`, `value`), so totals and components are
  never added together by accident; `tidyr::unnest()` gives the long
  form. Every filing is flagged for the accounting identities it fails
  (`consistent`, `inconsistencies`; balance sheet balances, totals equal
  their components, results follow from their parts, within 1 unit of
  currency), since the register publishes filings as filed. The field,
  group and identity maps are published under `brreg_regnskap` in
  `endpoints.json` for the MCP servers, and the flattening is verified
  against every structural shape of the 1,129,601 filings in the
  brreg-json-fetcher `data-2026-10` release (`data-raw/regnskap/`).
  Entities whose accounting plan the API does not serve (banks,
  insurers, pension funds) return the typed empty with
  `unsupported_plan` and a new `tidybrreg_warning_unsupported_plan`
  instead of an error.

## Breaking changes

* `brreg_download()` supports `type_output = "tibble"` and `"path"`
  only. The Arrow backend is withdrawn: BRREG's CSV fails in
  `arrow::read_csv_arrow()` on embedded newlines in quoted addresses,
  its JSON bulk is a pretty-printed array rather than NDJSON, and the
  path bypassed the dictionary. arrow, nanoparquet and duckdb are no
  longer Suggests.

* `get_brreg_dic()` returns columns `code`, `name`, `level` (`name`
  replaces `name_en`, which was wrong for `lang = "no"`), with
  attributes `source`, `lang` and `vintage`, and gains `source =
  c("auto", "klass", "bundled")` and `refresh`.

* `brreg_update_fields()` and the `changes` column of `brreg_updates()`
  gain a `path` column holding the raw JSON pointer of each patch leaf.

* Timestamps from the update feeds are `POSIXct` in UTC (previously
  parsed as local time); `since` keeps the precision of a `POSIXct`
  and is sent as a UTC instant; a `Date` means midnight UTC.

* `brreg_entity()` always carries `deleted` (logical) and `registry`.

* Valid empty results are typed zero-row tibbles everywhere
  (previously zero-column `tibble()`): search results carry `org_nr`,
  `name`, `legal_form`; roles, legal roles, konsern, signatur and
  prokura carry their full documented column set; update feeds carry
  their four (or seven) columns.

* The per-entity endpoints (`brreg_roles()`, `brreg_roles_legal()`,
  `brreg_konsern()`, `brreg_signatur()`, `brreg_prokura()`) no longer
  warn on HTTP 404; they return the typed empty with attribute
  `http_status = 404L`. HTTP 410 warns about deletion; other HTTP
  errors abort.

* Loading or attaching the package performs no filesystem or network
  access: the startup message about missing bulk data and the
  undocumented `.onLoad` override of bundled dictionaries from RDS
  files are gone.

## Typed conditions

Every error and warning now carries a class and fields; see
`?tidybrreg_conditions`. Errors: `tidybrreg_error_invalid_org_nr`,
`_invalid_filter`, `_not_found`, `_http`, `_result_window`,
`_invalid_since`, `_no_bundled_dictionary`. Warnings:
`tidybrreg_warning_deleted`, `_partial`, `_truncated`,
`_unknown_member`, `_bundled_fallback`, `_parse`.

## Fixes to the retained core

* `brreg_entity()` models deletion consistently: HTTP 200 with
  `respons_klasse = "SlettetEnhet"` (the form BRREG uses for nearly all
  deletions) and HTTP 410 both yield `deleted = TRUE`, a parsed
  `deletion_date`, every other observed field, and a warning. A
  vector of several organization numbers is rejected instead of
  silently querying the first. Nested HAL `_links` blocks
  (`organisasjonsform._links.self.href`) are stripped at any depth on
  both the live and bulk paths.

* `brreg_search()` aborts on unsupported filters (`bankrupt` for
  underenheter), aborts with `tidybrreg_error_result_window` before
  returning a partial population when a query exceeds BRREG's 10,000
  result window, reports truncation with `complete = FALSE` and a
  warning, aborts on a first-page HTTP failure, and warns on a later
  one instead of returning a silently partial result.

* `brreg_updates()` and `brreg_update_fields()` share one paginator:
  first-page failures abort, later failures warn and return the pages
  read with `complete = FALSE`; stopping on `max_pages` with a full
  last page warns; results carry `complete`, `pages_fetched` and
  `cursor`. Members of an update object the package does not model
  pass through as columns with a `tidybrreg_warning_unknown_member`.
  The roller feed honours `max_pages` and `verbose` (paginating on
  `afterId`) and rejects `include_changes`. Patch flattening handles
  any nesting depth identically on the flat and list-column paths.

* `brreg_download()` validates `refresh` (`TRUE`, `FALSE`, `"auto"`)
  and `cache`; `cache = FALSE` uses a temporary file instead of
  writing the payload to the cache directory anyway; `refresh = "auto"`
  revalidates against both `ETag` and `Last-Modified` and re-downloads
  when nothing can prove the cache current; download metadata
  (`last_modified` as UTC `POSIXct`) is attached as
  `attr(x, "brreg_download")` and written to a sidecar.

* Dictionary coercion is one rule on every path: the four numeric
  `capital_*` fields are numeric on bulk CSV as well as live JSON;
  parse failures are reported for every type, never abort the parse
  (the diagnostics table used to break on more than twenty failures),
  and the `brreg_parse_problems` table carries `n_failed`. A field the
  dictionary lists under two spellings keeps both observed values; a
  snake_case collision between unmapped fields is made unique rather
  than dropping the second.

* Dates and instants: konsern relation dates and Fullmakt birth dates
  accept both ISO and `DD.MM.YYYY`; `Last-Modified` headers parse in
  any locale.

* `brreg_label()` honours `lang = "no"` for every dictionary, is
  idempotent, leaves no stray `names` attribute on labelled columns,
  and preserves the input's attributes (`total_matches` survives
  `code =`). `options(tidybrreg.offline = TRUE)` keeps labelling off
  the network; KLASS failures fall back to the bundled dictionaries
  with a warning stating their vintage.

* `DESCRIPTION` carries the maintainer's real address. Provenance,
  licence and vintage of every bundled table are documented in
  `?tidybrreg_provenance`.

# tidybrreg 0.5.0

## Breaking changes

* Parsers no longer fabricate `field_dict` columns that the payload did
  not carry. `rename_and_coerce()` and `rename_from_dict()` previously
  materialized every dictionary column as typed `NA` when absent,
  asserting the full schema regardless of what the register emitted and
  making a removed upstream field indistinguishable from a present-null
  one. Emission is now batch-scoped, matching the `resigned` rule: a
  column appears when the field is observed anywhere in the batch, `NA`
  for records in that batch lacking it, absent entirely when unobserved.
  `parse_entities()` unions across the batch via `bind_rows()`, so
  multi-entity results are unchanged except that never-observed columns
  are gone. Single-entity `brreg_entity()` now returns roughly 61-63
  columns instead of a fixed 104. This also stops the enheter bulk
  parse from stamping twelve underenheter-only columns
  (`beliggenhetsadresse.*`, `oppstartsdato`, `datoEierskifte`,
  `nedleggelsesdato`) onto every enhet row.

* Array-valued fields now join on `"\n"` instead of `"; "` (bulk JSON)
  or `", "` (live JSON). Element text routinely contains commas and
  semicolons but never newlines, so only `"\n"` can be split back into
  the observed elements. Arrays of objects are serialized to JSON
  rather than pasted, which fixes `historiskeNavn` arriving as
  unusable text from `brreg_entity()` on the ~18% of enheter that have
  name history. The two JSON paths now agree with each other and with
  BRREG's own CSV rendering of addresses; note that the CSV joins
  wrapped-text fields such as `vedtektsfestetFormaal` with a space, so
  those remain non-identical across formats and cannot be reconciled
  without a per-field rule.

* `brreg_roles()`, `brreg_roles_legal()`, and the roller bulk parser no
  longer fabricate a `resigned` column. BRREG removed the underlying
  `fratraadt` field from the roles REST endpoint, `juridiskeroller`,
  and the totalbestand bulk on 2026-06-16, which had left `resigned`
  constant `FALSE` for every role. The column now appears only when a
  payload actually carries `fratraadt` (replays of pre-June data),
  with within-payload absence keeping the old `FALSE` semantics.
  `diff_roller_state()` already intersects its comparison set with the
  columns present on both sides, so mixed old/new states diff cleanly.
  `brreg_board_summary()` gains a column-tolerant active filter; the
  previous pre-guard collapsed to a scalar when `resigned` was absent
  and silently disabled the deregistered filter.

## New features

* New `brreg_konsern()` retrieves the hierarchical corporate group
  structure from the konsernstruktur endpoint BRREG added 2026-06-24.
  One row per node at any depth (live ASA groups nest six levels),
  root synthesized at level 0 as `KKKK` "Øverste mor" to match the
  endpoint's CSV variant, children carrying observed `knytningsform`,
  `grunnlag`, and relation dates. The endpoint returns 404 both for
  nonexistent organization numbers and for live entities in no group;
  `in_corporate_group` from `brreg_entity()` disambiguates.

* Name history (`historiskeNavn`, added by BRREG 2026-06-16/18) is
  captured. `brreg_sync()` ingests the `add /historiskeNavn/-` CDC
  patches for both enheter and underenheter into a `historiske_navn`
  state table, read by the new `brreg_historical_names()`. Rename
  events land in the changelog as `registry = "historiske_navn"`,
  `change_type = "name_history_added"`, carrying the superseded name
  and its validity interval.

* `brreg_sync()` gains a `format` argument (default `"csv"`,
  behaviour-preserving) forwarded to the bootstrap bulk download.
  `historiskeNavn` has no CSV column and no presence flag, so history
  predating the first sync exists only in the JSON bulk;
  `format = "json"` backfills it at bootstrap.

## Minor improvements and fixes

* `extract_paategninger()` parses inline annotation arrays on the JSON
  bulk path. Previously the boolean-flag matcher never fired on the
  serialized arrays, so a JSON-format bootstrap silently produced an
  empty påtegninger state; the CSV flag-then-fetch path is unchanged.

* Documentation corrected against the live bulk files: the enheter and
  underenheter CSVs are comma-delimited (not semicolon), and
  `kapital`, `vedtektsfestetFormaal`, and `paategninger` all have CSV
  columns today. `historiskeNavn` is the JSON-only field, and CSV
  carries påtegninger only as a `true`/`false` presence flag.

* The API monitor's schema probe also samples the per-entity roles
  endpoint and the konsernstruktur endpoint (ASA census guarantees
  group members in the sample), so roller field removals like
  `fratraadt` and new endpoints are visible to drift detection.
# tidybrreg 0.4.0

## New features

* New `brreg_signatur()` and `brreg_prokura()` retrieve signature
  (signaturrett) and procuration (prokura) authority from the
  Brønnøysund Fullmakt service (`data.brreg.no/fullmakt`). Signing
  authority — who may bind the entity, and under which combination rule
  — is held in a separate service from the roles in `brreg_roles()`,
  which report only who holds a seat. Each returns one row per person
  per registered combination, with `rule_status`/`rule_text`, birth
  date, and an English `role` looked up from `role_types` (which gains
  the six signing-mode codes `SIGN`, `SIFE`, `SIHV`, `PROK`, `POFE`,
  `POHV`).

## Minor improvements and fixes

* Request construction is consolidated behind a single internal factory
  (`brreg_http_req()`). The SSB KLASS request in `fetch_klass()` now
  flows through it — gaining the shared user agent, transient retry, and
  a `data.ssb.no`-scoped throttle — instead of being hand-built, and
  `brreg_req()` gains a `service` argument so the Enhetsregisteret and
  Fullmakt path roots share one configured request. No change to the
  Enhetsregisteret-facing API.

# tidybrreg 0.3.8

## Bug fixes

* `brreg_sync()` now populates `paategninger` state. The enheter bulk
  download (CSV) only carries påtegninger as a boolean presence flag, not
  the annotation content, so `extract_paategninger()` previously always
  produced empty state and `brreg_annotations()` returned nothing after a
  sync. The bootstrap now reads the flag (column `annotations`) and fetches
  the actual annotation content per flagged entity from the enheter
  endpoint. New internal helper `fetch_entity_paategninger()`.

# tidybrreg 0.3.7

## New features

* New bundled dataset [annotation_infotypes]: maps brreg påtegning
  `infotype` codes to English descriptions. Sourced from the brreg API
  reference (`NAVN`, `FADR`) and codes observed in live data (role codes
  used for missing-role annotations); unknown codes pass through.
* `brreg_annotations()` gains a `translate` argument. With
  `translate = TRUE` an `infotype_desc` column with English descriptions
  (from `annotation_infotypes`) is added after `infotype`. Default
  `FALSE`, so existing behaviour is unchanged.

## Documentation

* `field_dict` documentation now lists `numeric` among the coercion
  types (added in 0.3.6 for `capital_shares`).

# tidybrreg 0.3.6

## Bug fixes

* `field_dict`: `capital_shares` (`kapital.antallAksjer`) is now typed
  `numeric` instead of `integer`. The share count exceeds the 32-bit
  integer range for large-cap entities (e.g. Equinor ASA, 2,556,807,512
  shares), so `coerce_types()` silently produced `NA` with an
  "NAs introduced by coercion to integer range" warning. It now retains
  the value, consistent with the other `kapital.*` fields.
* Bundled `role_types` and `role_groups`: Norwegian role names
  (`Observatør`, `Regnskapsfører`, `Forretningsfører`, `FFØR`,
  `Helse, miljø og sikkerhet`) are now stored as UTF-8 escapes in
  `data-raw/build_dictionaries.R` and saved with UTF-8 encoding marking.
  String values are byte-identical to before; this only clears the
  R CMD check "non-ASCII strings" data warning.

## Internal

* `read_changelog()`: the arrow branch now references the partition
  column as `.data$sync_date` and imports the `rlang::.env` pronoun,
  removing the "no visible binding for global variable" check note.
  Runtime behaviour is unchanged.
* Tests: `field_dict` invariants aligned with the v0.3.5 dictionary —
  `api_path` is the unique key (multiple API-spelling variants map to a
  single `col_name`), and `numeric` is an accepted type.

# tidybrreg 0.3.4

## Roller CDC: field-level change detection

* `bootstrap_state()` now initializes the CDC cursor to the current
  tip (max event ID) at bootstrap time via `get_cdc_tip()`. Previously
  the cursor remained at 0 after bootstrap, causing the first CDC poll
  to replay the entire event history (~4.4M roller events, ~24M enheter
  events). This caused OOM and timeout failures on Cloud Run.
* `bootstrap_state(roller_method = "cdc")` skips the roller
  totalbestand download entirely. Writes an empty state table and
  builds state incrementally via per-org `brreg_roles()` calls.
  Reduces bootstrap from 32 GiB RAM / 30+ minutes to <10 seconds
  and negligible memory.
* `paginate_cdc()` gains a `max_pages` parameter and a safety guard:
  if `cursor_id == 0` (no prior sync), pagination caps at 5 pages and
  emits a `cli::cli_warn()`. Belt-and-suspenders — should never trigger
  after a correct bootstrap.
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
