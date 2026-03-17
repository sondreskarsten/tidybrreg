# Package architecture

This article documents tidybrreg’s internal architecture. It is intended
for contributors and users who want to understand the data flow from the
brreg API through parsing, storage, and panel construction.

For the full technical specification (390 lines), see
[ARCHITECTURE.md](https://github.com/sondreskarsten/tidybrreg/blob/main/ARCHITECTURE.md)
in the repository root.

## Data flow overview

    ┌─────────────────────────────────────────────────────────────────┐
    │                     brreg API (data.brreg.no)                   │
    │                                                                 │
    │  /enheter/{orgnr}          Single entity JSON                   │
    │  /enheter?navn=...         Filtered search (paginated)          │
    │  /enheter/lastned/csv      Bulk CSV  (152 MB, ~90 cols)         │
    │  /enheter/lastned          Bulk JSON (196 MB, ~67 cols)         │
    │  /roller/totalbestand      Bulk roles JSON (131 MB)             │
    │  /oppdateringer/enheter    CDC stream (HAL format)              │
    │  /oppdateringer/roller     CDC stream (CloudEvents format)      │
    └──────────────────────────────┬──────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │         HTTP layer          │
                    │  R/request.R: brreg_req()   │
                    │  httr2 + retry + throttle   │
                    └──────────────┬──────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
       ┌──────┴──────┐     ┌──────┴──────┐     ┌──────┴──────┐
       │ Pipeline 1  │     │ Pipeline 2  │     │ Pipeline 2  │
       │ Single JSON │     │ Bulk CSV    │     │ Bulk JSON   │
       │             │     │             │     │             │
       │ flatten_json│     │ readr::     │     │ jsonlite::  │
       │ rename_dict │     │ read_csv    │     │ fromJSON    │
       │ coerce_types│     │             │     │ flatten_    │
       │             │     │             │     │ list_cols   │
       │             │     │             │     │ drop_links  │
       └──────┬──────┘     └──────┬──────┘     └──────┬──────┘
              │                   │                    │
              │            ┌──────┴────────────────────┘
              │            │
              │     ┌──────┴──────┐
              │     │ rename_and_ │
              │     │ coerce()    │
              │     │ field_dict  │
              │     │ + to_snake  │
              │     └──────┬──────┘
              │            │
              └────────────┤
                           │
                  ┌────────┴────────┐
                  │  Flat tibble    │
                  │  atomic cols    │
                  │  English names  │
                  └────────┬────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────┴──────┐    │     ┌──────┴──────┐
       │  Return to  │    │     │  Snapshot   │
       │  user       │    │     │  engine     │
       │             │    │     │  write_     │
       │             │    │     │  parquet    │
       └─────────────┘    │     │  + manifest │
                          │     └──────┬──────┘
                          │            │
                   ┌──────┴──────┐    │
                   │  Label      │    │
                   │  system     │    │
                   │  brreg_     │    │
                   │  label()    │    │
                   └─────────────┘    │
                                      │
                         ┌────────────┴────────────┐
                         │     Snapshot store       │
                         │  Hive-partitioned        │
                         │  Parquet files           │
                         │                          │
                         │  enheter/                │
                         │    snapshot_date=.../     │
                         │      data.parquet        │
                         │      raw/*.gz            │
                         │  manifest.json           │
                         └────────────┬─────────────┘
                                      │
                     ┌────────────────┼────────────────┐
                     │                │                │
              ┌──────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐
              │ brreg_panel │ │ brreg_      │ │ brreg_      │
              │ multi-snap  │ │ events()    │ │ series()    │
              │ LOCF        │ │ diff two    │ │ arbitrary   │
              │             │ │ snapshots   │ │ aggregation │
              └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
                     │               │               │
                     └───────────────┼───────────────┘
                                     │
                            ┌────────┴────────┐
                            │  as_brreg_      │
                            │  tsibble()      │
                            │  → tidyverts    │
                            └─────────────────┘

## Key design decisions

**Flat tidy output.** JSON nested objects and list columns are
algorithmically flattened to atomic types. Character vectors are
collapsed with `"; "`, data frames serialized to JSON strings, HAL links
dropped. Both CSV and JSON paths share
[`rename_and_coerce()`](https://sondreskarsten.github.io/tidybrreg/reference/rename_and_coerce.md).

**Zero-drop policy.** Unknown API fields pass through with auto
snake_case names. `arrow::open_dataset(unify_schemas = TRUE)` handles
schema evolution across snapshot dates.

**Raw file provenance.** Every snapshot stores the original `.gz`
alongside processed Parquet. The JSON manifest records HTTP headers
(`Last-Modified` for data vintage, ETag for change detection), file
hashes, and record counts.

**Two panel paths.** Multi-snapshot diff
([`brreg_panel()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_panel.md))
for historical analysis with old+new values. CDC replay
([`brreg_replay()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_replay.md))
for forward reconstruction from a single base.

See
[ARCHITECTURE.md](https://github.com/sondreskarsten/tidybrreg/blob/main/ARCHITECTURE.md)
for the complete specification.
