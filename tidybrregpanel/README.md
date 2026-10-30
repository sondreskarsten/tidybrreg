# tidybrregpanel

Managed state and longitudinal analysis for Norway's business registry,
built on [tidybrreg](https://github.com/sondreskarsten/tidybrreg).

tidybrreg is the typed client: fifteen functions, one per register
endpoint, no persistence. tidybrregpanel is everything that keeps
state on disk or derives quantities over time:

| Area | Functions |
|---|---|
| Snapshot store (Hive-partitioned Parquet) | `brreg_snapshot()`, `brreg_import()`, `brreg_snapshots()`, `brreg_open()`, `brreg_cleanup()`, `brreg_data_dir()`, `brreg_manifest()`, `brreg_status()` |
| Synchronised mirror with changelog | `brreg_sync()`, `brreg_sync_status()`, `brreg_changes()`, `brreg_change_summary()` |
| Reconstruction and events | `brreg_replay()`, `brreg_events()`, `diff_roller_state()` |
| Panels and series | `brreg_panel()`, `brreg_flows()`, `brreg_series()`, `as_brreg_tsibble()` |
| Annotations and name history | `brreg_annotations()`, `brreg_annotation_summary()`, `brreg_historical_names()` |
| Harmonisation (SSB KLASS) | `brreg_harmonize_kommune()`, `brreg_harmonize_nace()` |
| Governance | `brreg_board_summary()`, `brreg_board_network()`, `brreg_network()`, `brreg_survival_data()` |

All retrieval goes through tidybrreg, and internal parsers are reached
through `tidybrreg:::` (the one deliberate `:::` dependency in the
ecosystem, so the core keeps its exact fifteen exports).

## Installation

```r
install.packages(c("tidybrreg", "tidybrregpanel"),
  repos = c("https://sondreskarsten.r-universe.dev", "https://cloud.r-project.org"))

# A parquet backend
install.packages("nanoparquet")  # lightweight
install.packages("arrow")        # lazy queries via brreg_open()
```

## Quick start

```r
library(tidybrreg)
library(tidybrregpanel)

brreg_snapshot("enheter")
brreg_snapshot("enheter", format = "json")   # carries kapital.*, historiskeNavn
brreg_snapshots()

panel <- brreg_panel(frequency = "year", cols = c("employees", "nace_1", "legal_form"))
brreg_series(.vars = "employees", by = "legal_form") |> as_brreg_tsibble()

brreg_sync(types = c("enheter", "roller"))
brreg_changes(registry = "roller", change_type = "entry")
```

See the vignettes: `panels`, `roller-cdc`, `governance`, `architecture`,
and `ARCHITECTURE.md` for the data flow from the API through parsing,
storage, panel construction and time series.

## Status

This package carries the managed subsystem exactly as it was in
tidybrreg 0.5.0 (commit `c9bd992`), moved rather than rewritten. The
defects recorded against that subsystem in the
[stress-test evaluation](https://github.com/sondreskarsten/tidybrreg-stresstest)
(flows bias D-50..D-52, sync loss D-36/D-38/D-43, harmonisation
D-78..D-80, snapshot layout D-54, manifest D-55/D-58/D-102) are open
work here, tracked in the tidybrreg issue tracker with the
`scope:deferred` label. The package is not CRAN-bound.
