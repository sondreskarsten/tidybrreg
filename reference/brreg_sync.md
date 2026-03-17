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
  verbose = TRUE
)
```

## Arguments

- types:

  Character vector of streams to sync. Default syncs all three entity
  types.

- size:

  Integer. CDC page size per API call (max 10000).

- verbose:

  Logical. Print progress messages.

## Value

A list with sync summary: events processed per type, changelog rows
written, elapsed time.

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
[`brreg_sync_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_sync_status.md),
[`brreg_annotations()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_annotations.md),
[`brreg_status()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_status.md)

## Examples

``` r
if (FALSE) { # interactive()
# \donttest{
brreg_sync()
brreg_sync_status()
# }
}
```
