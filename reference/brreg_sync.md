# Synchronize local state with the brreg CDC stream

Maintains a local mirror of the Enhetsregisteret by applying incremental
CDC (change data capture) events to a persistent state table. On first
run, bootstraps from a bulk download. Subsequent runs poll the CDC
endpoints from the last cursor position and apply mutations.

## Usage

``` r
brreg_sync(
  types = c("enheter", "underenheter", "roller"),
  size = 10000L,
  roller_method = c("bulk", "cdc"),
  verbose = TRUE
)
```

## Arguments

- types:

  Character vector of streams to sync. Default syncs all four.

- size:

  Integer. CDC page size per API call (max 10000).

- roller_method:

  One of `"bulk"` (default) or `"cdc"`. `"bulk"` downloads the full
  totalbestand (~131 MB) and computes a field-level diff against
  previous state — fast and produces granular changelogs. `"cdc"`
  fetches current roles per-org via the API for each CDC event — slower
  but provides sub-daily attribution when syncing multiple times per
  day.

- verbose:

  Logical. Print progress messages.

## Value

A list with sync summary: events processed per type, changelog rows
written, elapsed time.

## Details

Four state files are maintained:

- `enheter.parquet` — main entities (~1M rows)

- `underenheter.parquet` — sub-entities (~500K rows)

- `roller.parquet` — all roles (~3.4M rows)

- `paategninger.parquet` — registry annotations

Every mutation is logged to a Hive-partitioned changelog under
`state/changelog/sync_date={date}/`. The changelog drives
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
and
[`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md).

## Write ordering

Changelog is written first (WAL), then state files, then cursor. If a
crash occurs between state and cursor, the next sync replays from the
old cursor. Mutations are idempotent (upsert by org_nr), so replay is
safe.

## See also

[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md)
to check current state,
[`brreg_changes()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_changes.md)
to query the changelog,
[`brreg_flows()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_flows.md)
for entry/exit counts.

Other tidybrreg data management functions:
[`brreg_annotation_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotation_summary.md),
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md),
[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md),
[`diff_roller_state()`](https://sondreskarsten.github.io/tidybrreg/reference/diff_roller_state.md),
[`read_changelog()`](https://sondreskarsten.github.io/tidybrreg/reference/read_changelog.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# \donttest{
brreg_sync()
brreg_sync_status()
# }
}
```
