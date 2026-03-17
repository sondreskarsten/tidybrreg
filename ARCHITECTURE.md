# tidybrreg architecture

Technical documentation for the tidybrreg R package (v0.2.0). Covers the
complete data flow from the Norwegian Business Registry API through
parsing, storage, panel construction, and time series output.

## The data source

The Brønnøysund Register Centre maintains Norway’s Central Coordinating
Register for Legal Entities (Enhetsregisteret) at `data.brreg.no`. The
API exposes three registries:

| Registry         | Content                                                          | Entities         | API base                             |
|------------------|------------------------------------------------------------------|------------------|--------------------------------------|
| **Enheter**      | Main legal entities (companies, associations, government bodies) | ~1.96M           | `/enhetsregisteret/api/enheter`      |
| **Underenheter** | Sub-entities / establishments (branch offices, plants)           | ~950K            | `/enhetsregisteret/api/underenheter` |
| **Roller**       | Board members, officers, auditors, shareholders for all entities | ~5M role records | `/enhetsregisteret/api/roller`       |

Each registry has multiple access patterns:

| Access pattern      | Enheter                         | Underenheter                        | Roller                                    |
|---------------------|---------------------------------|-------------------------------------|-------------------------------------------|
| Single lookup       | `/enheter/{orgnr}`              | `/underenheter/{orgnr}`             | `/enheter/{orgnr}/roller`                 |
| Filtered search     | `/enheter?navn=...`             | `/underenheter?navn=...`            | —                                         |
| Bulk CSV            | `/enheter/lastned/csv` (152 MB) | `/underenheter/lastned/csv` (59 MB) | —                                         |
| Bulk JSON           | `/enheter/lastned` (196 MB)     | `/underenheter/lastned` (75 MB)     | `/roller/totalbestand` (131 MB)           |
| CDC updates         | `/oppdateringer/enheter` (HAL)  | `/oppdateringer/underenheter` (HAL) | `/oppdateringer/roller` (CloudEvents)     |
| Reverse role lookup | —                               | —                                   | `/roller/enheter/{orgnr}/juridiskeroller` |

The CSV and JSON bulk endpoints for enheter/underenheter return
different column sets. JSON carries fields absent from CSV
(e.g. `kapital.*`, `vedtektsfestetFormaal`, `aktivitet`,
`paategninger`). CSV may carry fields absent from JSON (e.g. additional
registration dates, dissolution dates). Neither is a superset of the
other.

The roller registry has no CSV bulk download. The `/roller/totalbestand`
endpoint returns a gzipped JSON array where each element mirrors the
per-entity `/enheter/{orgnr}/roller` response: deeply nested
rollegrupper → roller → person/enhet structure.

## Package file layout

    R/
    ├── request.R          48 lines   HTTP layer: brreg_req(), to_snake(), compact()
    ├── validate.R         30 lines   Modulus-11 org number validation
    ├── parse.R            96 lines   Single-entity JSON → tibble (API responses)
    ├── download.R        312 lines   Bulk download + 3 parsers (CSV, JSON, roller)
    ├── entities.R        191 lines   brreg_entity(), brreg_search() (enheter + underenheter)
    ├── roles.R           197 lines   brreg_roles(), brreg_roles_legal(), brreg_board_summary()
    ├── updates.R         130 lines   brreg_updates() (enheter, underenheter, roller CDC)
    ├── label.R           183 lines   brreg_label(), get_brreg_dic(), build_label_map()
    ├── snapshot.R        289 lines   Snapshot engine: save, import, list, open, cleanup
    ├── manifest.R         89 lines   JSON provenance catalog
    ├── parquet-utils.R    56 lines   Tiered parquet read/write (arrow > nanoparquet)
    ├── panel.R           205 lines   brreg_panel(), LOCF date resolution, entry/exit coding
    ├── replay.R          140 lines   brreg_replay() — CDC forward reconstruction
    ├── events.R          127 lines   brreg_events() — snapshot diff (entries, exits, changes)
    ├── series.R          114 lines   brreg_series() — arbitrary-variable aggregation
    ├── tsibble.R          54 lines   as_brreg_tsibble() — tsibble conversion
    ├── harmonize.R       132 lines   Municipality and NACE code concordance
    ├── governance.R      134 lines   Board network (tidygraph) + survival data
    ├── tidybrreg-package.R 93 lines  Dataset docs: field_dict, legal_forms, role_types, role_groups
    └── zzz.R              27 lines   .brregEnv cache, globalVariables()

## Two parsing pipelines

All data entering the package passes through one of two pipelines. Both
produce flat tibbles with atomic columns only (no list columns). Both
apply the same rename-and-coerce step at the end.

### Pipeline 1: Single-entity API responses (parse.R)

Used by
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
and
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md).
The brreg API returns nested JSON for each entity.

    API JSON → flatten_json()  → rename_from_dict() → coerce_types() → tibble
               recursive dot     field_dict lookup     Date/integer/
               notation          + to_snake() for       logical cast
                                 unknown fields

[`flatten_json()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_json.md)
recursively walks the JSON tree and produces a flat named list with
dot-notation keys (`forretningsadresse.kommune`).
[`rename_from_dict()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_from_dict.md)
maps known keys via the `field_dict` tibble (49 rows: api_path →
col_name + type). Unknown keys pass through with auto-generated
snake_case names.
[`coerce_types()`](https://sondreskarsten.github.io/tidybrreg/reference/coerce_types.md)
casts each dict-mapped column to its declared type.

All 49 dict-mapped columns appear in every output row, even when absent
from the API response (filled with typed `NA`). This guarantees a stable
column contract across entities.

### Pipeline 2: Bulk downloads (download.R)

Used by
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md)
and
[`brreg_snapshot()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_snapshot.md).
Three sub-pipelines, all ending at the same
[`rename_and_coerce()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_and_coerce.md):

**CSV path** (`parse_bulk_csv`):

    .csv.gz → readr::read_csv(col_types = all character) → rename_and_coerce()

**JSON path** (`parse_bulk_json`):

    .json.gz → jsonlite::fromJSON(flatten = TRUE)
             → flatten_list_columns()  → drop_hal_links() → rename_and_coerce()

**Roller path** (`parse_roles_bulk`):

    .json.gz → jsonlite::fromJSON(simplifyVector = FALSE)
             → for each entity: flatten_roles(entity, org_nr)
             → bind_rows()

### The algorithmic unnesting step (flatten_list_columns)

`jsonlite::fromJSON(flatten = TRUE)` expands nested JSON objects to
dot-notation columns but leaves JSON arrays as R list columns. The brreg
JSON bulk download produces six types of list columns:

| Column                             | R type            | Content                              | Flattening rule                                                                        |
|------------------------------------|-------------------|--------------------------------------|----------------------------------------------------------------------------------------|
| `forretningsadresse.adresse`       | `character[1-3]`  | Street address lines                 | `paste(collapse = "; ")`                                                               |
| `postadresse.adresse`              | `character[1-3]`  | Postal address lines                 | `paste(collapse = "; ")`                                                               |
| `aktivitet`                        | `character[1-10]` | Activity descriptions                | `paste(collapse = "; ")`                                                               |
| `vedtektsfestetFormaal`            | `character[1-11]` | Articles of association              | `paste(collapse = "; ")`                                                               |
| `paategninger`                     | `data.frame`      | Endorsements (infotype, tekst, dato) | [`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html) |
| `links`, `organisasjonsform.links` | `list[0]`         | HAL hypermedia links                 | Dropped entirely                                                                       |

[`flatten_cell()`](https://sondreskarsten.github.io/tidybrreg/reference/flatten_cell.md)
dispatches on runtime type: atomic vectors are collapsed with
[`paste()`](https://rdrr.io/r/base/paste.html), data frames are
serialized to JSON strings (preserving all fields for later extraction),
empty lists and NULLs become `NA_character_`. This produces a flat
tibble with zero list columns.

HAL `_links` columns are metadata about API navigation, not entity data.
They are dropped by
[`drop_hal_links()`](https://sondreskarsten.github.io/tidybrreg/reference/drop_hal_links.md)
(regex on column names ending in `links`).

### The shared rename step (rename_and_coerce)

Both CSV and JSON paths share this function. It does two things:

1.  **Rename**: Look up each column name (lowercased) in
    `field_dict$api_path`. If found, rename to `field_dict$col_name`. If
    not found, apply
    [`to_snake()`](https://sondreskarsten.github.io/tidybrreg/reference/to_snake.md)
    (camelCase/dot.notation → snake_case). Zero columns are dropped.

2.  **Coerce**: For each dict-mapped column, cast to the declared type:
    `Date` via [`as.Date()`](https://rdrr.io/r/base/as.Date.html),
    `integer` via [`as.integer()`](https://rdrr.io/r/base/integer.html),
    `logical` via [`as.logical()`](https://rdrr.io/r/base/logical.html),
    `character` via
    [`as.character()`](https://rdrr.io/r/base/character.html).

### Why CSV and JSON produce different columns

The brreg API does not guarantee column parity between CSV and JSON bulk
downloads. In practice:

- **65 columns are shared** between the two formats.
- **~25 columns appear only in CSV** (additional registration dates,
  dissolution dates, foreign insolvency fields).
- **~2-5 columns appear only in JSON** (kapital.*, hjelpeenhetskode.*,
  respons_klasse).
- These sets shift over time as brreg adds fields to one format before
  the other.

The package handles this by applying the same rename-and-coerce logic to
whatever columns are present, passing through unknowns rather than
hardcoding parity.

## The snapshot store

### Directory structure

    tools::R_user_dir("tidybrreg", "data")/
    ├── enheter/
    │   ├── snapshot_date=2024-01-01/
    │   │   ├── data.parquet          ← processed flat tibble
    │   │   └── raw/
    │   │       └── enheter_bulk.csv.gz  ← original download (provenance)
    │   ├── snapshot_date=2024-07-01/
    │   │   ├── data.parquet
    │   │   └── raw/
    │   │       └── enheter_bulk.json.gz
    │   └── ...
    ├── underenheter/
    │   └── snapshot_date=.../
    ├── roller/
    │   └── snapshot_date=.../
    └── manifest.json                 ← provenance catalog

Partitioning is Hive-style (`snapshot_date=YYYY-MM-DD` directory names).
[`arrow::open_dataset()`](https://arrow.apache.org/docs/r/reference/open_dataset.html)
with `hive_partition(snapshot_date = date32())` reads the entire
collection as a lazy dataset with partition pruning — filtering on
`snapshot_date` skips unneeded files entirely.

### Parquet backend tiers

The package never depends on arrow or nanoparquet at the `Imports`
level. Both are in `Suggests`. Internal dispatch:

    parquet_tier() returns:
      "arrow"       → arrow::write_parquet(), arrow::read_parquet()
      "nanoparquet"  → nanoparquet::write_parquet(), nanoparquet::read_parquet()
      "none"         → error with install instructions

[`write_parquet_safe()`](https://sondreskarsten.github.io/tidybrreg/reference/write_parquet_safe.md)
writes to a tempfile first, then renames atomically (crash-safe).
[`read_parquet_safe()`](https://sondreskarsten.github.io/tidybrreg/reference/read_parquet_safe.md)
reads and converts to tibble.

arrow enables lazy queries
([`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md)
→ [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
→
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html)).
nanoparquet is read/write only, no lazy queries — functions that need
lazy access
([`brreg_open()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_open.md))
require arrow explicitly.

### The snapshot lifecycle

    brreg_snapshot("enheter", format = "json")
      │
      ├─ brreg_download(type = "enheter", format = "json", type_output = "path")
      │    ├─ Downloads .gz to tools::R_user_dir("tidybrreg", "cache")/enheter_bulk.json.gz
      │    ├─ Stores ETag in .etag sidecar file
      │    └─ Stores httr2 response object in .brregEnv for manifest
      │
      ├─ Copies raw .gz to snapshot partition dir /raw/
      │
      ├─ Parses: parse_bulk_json() or parse_bulk_csv() or parse_roles_bulk()
      │
      ├─ write_parquet_safe() → data.parquet in partition dir
      │
      └─ write_manifest_entry() → appends to manifest.json

[`brreg_import()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_import.md)
follows the same path but reads from a user-supplied file instead of
downloading. It does not create a manifest entry (no HTTP metadata to
record).

### The manifest

`manifest.json` is a JSON file with a `downloads` array. Each entry
records:

| Field                | Source                                                              | Purpose                                             |
|----------------------|---------------------------------------------------------------------|-----------------------------------------------------|
| `id`                 | `"{type}_{date}"`                                                   | Dedup key                                           |
| `type`               | Function argument                                                   | `"enheter"` / `"underenheter"` / `"roller"`         |
| `snapshot_date`      | Function argument                                                   | Date the snapshot represents                        |
| `endpoint`           | Constructed URL                                                     | Which brreg endpoint was called                     |
| `format`             | Function argument                                                   | `"csv"` or `"json"`                                 |
| `download_timestamp` | [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html)                | When the download occurred (wall clock)             |
| `last_modified`      | HTTP `Last-Modified` header                                         | When brreg last regenerated the file (data vintage) |
| `etag`               | HTTP `ETag` header                                                  | Server-side change detection token                  |
| `file_hash`          | [`rlang::hash_file()`](https://rlang.r-lib.org/reference/hash.html) | Integrity verification (XXH128)                     |
| `record_count`       | `nrow(dat)`                                                         | Number of rows in processed output                  |
| `raw_path`           | File path                                                           | Location of preserved raw .gz                       |
| `parquet_path`       | File path                                                           | Location of processed parquet                       |

The `last_modified` field is the critical timestamp for CDC bridging. It
represents when brreg regenerated the bulk file, not when you downloaded
it. To bridge to CDC updates without gaps, fetch updates starting from
`last_modified - 1 day` (deliberate overlap), then deduplicate.

## Two paths to panel data

### Path A: Multi-snapshot diff (brreg_panel)

Requires 2+ snapshots. Produces a firm × period panel where each row is
an entity at a point in time.

    brreg_panel(frequency = "year", cols = c("employees", "nace_1"))
      │
      ├─ brreg_snapshots() → list available partitions with dates
      │
      ├─ generate_year_targets(from, to) → target dates (e.g. 2024-12-31, 2025-12-31)
      │
      ├─ resolve_snapshot_dates(available, targets) → LOCF mapping
      │    Each target date maps to the most recent snapshot on or before it.
      │    Target 2024-12-31 with snapshots [2024-01-01, 2024-07-01, 2025-01-01]
      │    → uses 2024-07-01 (nearest prior).
      │
      ├─ Read needed snapshots (arrow lazy or nanoparquet eager)
      │
      ├─ inner_join with mapping → adds period and snapshot_date columns
      │
      └─ add_entry_exit() → is_entry (first appearance), is_exit (last appearance)

LOCF (last observation carried forward): when a target period falls
between two snapshots, the earlier snapshot’s data carries forward. This
means the panel at “2024-12-31” shows the state from the “2024-07-01”
snapshot if no later snapshot exists before year-end.

### Path B: Single snapshot + CDC replay (brreg_replay)

Requires one base snapshot + a CDC update stream from
`brreg_updates(include_changes = TRUE)`.

    brreg_replay(base, updates, target_date = "2025-12-31")
      │
      ├─ Filter updates to timestamp <= target_date
      │
      ├─ Sort updates chronologically
      │
      └─ For each update, by change_type:
           "Ny"       → Insert new row (with patch fields if available)
           "Endring"  → Update fields in-place via patch
           "Sletting" → Delete row
           "Fjernet"  → Delete row

CDC field-level changes are only available from September 2025. Before
that date, only the change type is recorded — the package can
insert/delete entities but cannot reconstruct which fields changed. For
pre-2025 field-level changes, use
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
(snapshot diff) instead.

Patch field mapping: CDC patches use camelCase slash-separated paths
(`forretningsadresse/postnummer`).
[`lookup_patch_field()`](https://sondreskarsten.github.io/tidybrreg/reference/lookup_patch_field.md)
converts these to `field_dict` column names or auto snake_case.

### When to use which

| Situation                                  | Use                                                                                                                     |
|--------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| You have multiple historical snapshots     | [`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md)                                  |
| You have one snapshot + want future states | [`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md)                                |
| You need old AND new values for changes    | [`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md) (snapshot diff gives both)     |
| You need change events but only have CDC   | [`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md) (CDC gives new values only)    |
| You need pre-September 2025 field changes  | [`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md) (CDC had no field detail then) |

## Time series with arbitrary variables

[`brreg_series()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_series.md)
accepts character vectors for variables, functions, and grouping:

``` r
brreg_series(
  .vars = "employees",                              # any column name(s)
  .fns  = list(avg = mean, total = sum, sd = sd),   # any summary function(s)
  by    = c("legal_form", "municipality_code"),      # any grouping column(s)
  frequency = "year"
)
```

Output columns are named `{variable}_{function}` (e.g. `employees_avg`,
`employees_total`). When `.vars = NULL`, counts entities per period.

The return value carries a `brreg_panel_meta` attribute with `index`,
`key`, and `frequency` fields.
[`as_brreg_tsibble()`](https://sondreskarsten.github.io/tidybrreg/reference/as_brreg_tsibble.md)
uses this to convert to tsibble automatically:

``` r
brreg_series(.vars = "employees", by = "legal_form") |>
  as_brreg_tsibble()
# → tsibble with index = period, key = legal_form, regular = FALSE
```

`regular = FALSE` is mandatory because brreg snapshots are irregularly
spaced (daily, weekly, monthly — whatever the user accumulated).

## Snapshot diffing (brreg_events)

Compares two dated snapshots and returns a tibble of events:

| event_type | Meaning                                         | Detection                                 |
|------------|-------------------------------------------------|-------------------------------------------|
| `"entry"`  | Entity appears in `date_to` but not `date_from` | `setdiff(new_ids, old_ids)`               |
| `"exit"`   | Entity appears in `date_from` but not `date_to` | `setdiff(old_ids, new_ids)`               |
| `"change"` | Field value differs for same entity             | Column-by-column comparison on common IDs |

Change events include both `value_from` and `value_to` — this is the key
advantage over CDC, which provides only new values.

## The labelling system

Follows the eurostat package pattern: codes by default, labels on
demand.

    brreg_entity("923609016")                    → legal_form = "ASA"
    brreg_entity("923609016", type = "label")    → legal_form = "Public limited company"
    brreg_entity("923609016") |> brreg_label()   → legal_form = "Public limited company"
    brreg_entity("923609016") |>
      brreg_label(code = "legal_form")           → legal_form = "Public limited company"
                                                   legal_form_code = "ASA"  (preserved)

[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
is polymorphic: works on data frames (replaces coded columns) and
character vectors (returns labelled vector). The `code =` argument keeps
original codes in a `_code` suffixed column.

Label lookup sources: - `legal_forms` (44 rows, bundled) — legal form
codes - `role_types` (18 rows, bundled) — role codes - `role_groups` (15
rows, bundled) — role group codes - `nace_codes` (1783 rows,
sysdata.rda) — NACE industry codes - `sector_codes` (33 rows,
sysdata.rda) — institutional sector codes - SSB Klass API (live, cached
in `.brregEnv`) — NACE and sector codes fetched on demand if sysdata is
stale

## CDC update formats

The enheter/underenheter and roller CDC endpoints use different formats:

**Enheter/Underenheter** — HAL JSON:

    /oppdateringer/enheter?dato=2026-03-15T00:00:00.000Z&size=100&includeChanges=true
    → { _embedded: { oppdaterteEnheter: [
        { oppdateringsid: 123, organisasjonsnummer: "923609016",
          endringstype: "Endring", dato: "2026-03-15T10:30:00.000",
          endringer: ["replace", "/antallAnsatte", "21500", ...] }
      ]}}

Field-level changes (`endringer`) are a flat interleaved array:
`["operation", "/path", "value", ...]`.
[`parse_patch()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_patch.md)
restructures this to a tibble with columns `operation`, `field`,
`new_value`.

**Roller** — CloudEvents:

    /oppdateringer/roller?afterTime=2026-03-15T00:00:00.000Z&size=100
    → [{ specversion: "1.0", id: "123",
         source: "https://data.brreg.no/.../enheter/923609016/roller",
         type: "no.brreg.enhetsregisteret.rolle.oppdatert",
         time: "2026-03-15T10:30:00.000Z",
         data: { organisasjonsnummer: "923609016" } }]

Roller CDC provides only which entity had role changes, not the actual
role data. To get the new state, fetch `/enheter/{orgnr}/roller` for
each changed entity.

## Dependency architecture

    Imports (always available):
      cli, dplyr, httr2 (>= 1.0.0), jsonlite, readr, rlang, tibble

    Suggests (optional, feature-gated):
      arrow (>= 12.0.0)    → lazy dataset queries, JSON arrow reader
      nanoparquet (>= 0.3.0) → lightweight parquet read/write
      duckdb                → ASOF joins for complex panel queries
      klassR                → SSB KLASS correspondence tables
      tidygraph             → director interlock networks
      tidyr                 → fill() for LOCF in panels
      tsibble               → temporal data structure
      curl                  → has_internet() in examples

Every Suggests dependency is gated with
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) or
[`rlang::check_installed()`](https://rlang.r-lib.org/reference/is_installed.html).
The core API functions (entity, search, roles, download CSV, updates,
validate, label) work with Imports only.

## Reference data

| Dataset        | Rows | Source                     | Used by                                                                                                                                                                                                                                                                                        |
|----------------|------|----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `field_dict`   | 49   | Manual curation            | [`rename_from_dict()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_from_dict.md), [`rename_and_coerce()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_and_coerce.md), [`coerce_types()`](https://sondreskarsten.github.io/tidybrreg/reference/coerce_types.md) |
| `legal_forms`  | 44   | brreg API + manual English | [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md), [`build_label_map()`](https://sondreskarsten.github.io/tidybrreg/reference/build_label_map.md)                                                                                                         |
| `role_types`   | 18   | brreg API + manual English | `lookup_role()`, [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)                                                                                                                                                                                        |
| `role_groups`  | 15   | brreg API + manual English | `lookup_role_group()`, [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)                                                                                                                                                                                  |
| `nace_codes`   | 1783 | SSB Klass API              | [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md) (sysdata.rda, updated via [`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md))                                                                                   |
| `sector_codes` | 33   | SSB Klass API              | [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md) (sysdata.rda, updated via [`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md))                                                                                   |
