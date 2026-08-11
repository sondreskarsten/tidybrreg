# D-49 Event Date Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `brreg_changes(from, to)` and `brreg_change_summary(from, to)` filter by each event's timestamp date instead of the changelog sync partition date.

**Architecture:** Keep `sync_date` as storage metadata only. Read the changelog through the existing Arrow or nanoparquet path, normalize the event timestamp prefix to `Date`, and apply inclusive `from`/`to` bounds in one shared post-read helper so both backends have identical semantics.

**Tech Stack:** R 4.6.1, testthat 3e, dplyr, Arrow/nanoparquet, devtools.

## Global Constraints

- Develop and test with the local R installation.
- Use the remote stress-test runner for integration validation.
- Preserve the exported function signatures and eight-column changelog schema.
- Make only the D-49 correctness change; do not combine adjacent defect fixes.

---

### Task 1: Filter changelog bounds by event date

**Files:**
- Create: `tests/testthat/test-changes.R`
- Modify: `R/state.R`
- Modify: `NEWS.md`

**Interfaces:**
- Consumes: `write_changelog(changes, sync_date)`, `read_changelog(from, to, registry, change_type)`, and exported `brreg_changes()`.
- Produces: unchanged public APIs whose `from` and `to` bounds are inclusive event-date filters.

- [x] **Step 1: Write the failing test**

```r
test_that("brreg_changes filters late-arriving events by event date", {
  skip_if(tidybrreg:::parquet_tier() == "none")
  withr::local_options(brreg.data_dir = withr::local_tempdir())

  changes <- tibble::tibble(
    timestamp = c("2026-08-05T23:59:59Z", "2026-08-06T00:00:00Z"),
    org_nr = c("111111111", "222222222"),
    registry = "enheter",
    change_type = "entry",
    field = NA_character_,
    value_from = NA_character_,
    value_to = NA_character_,
    update_id = 1:2
  )
  tidybrreg:::write_changelog(changes, sync_date = as.Date("2026-08-06"))

  result <- brreg_changes(from = as.Date("2026-08-06"))

  expect_equal(result$org_nr, "222222222")
})
```

- [x] **Step 2: Run the focused test to verify RED**

Run: `Rscript -e "devtools::test(filter='changes', reporter='summary')"`

Expected: FAIL because the result includes both organisation numbers from the `sync_date=2026-08-06` partition.

- [x] **Step 3: Implement the minimal shared event-date filter**

Add an internal helper in `R/state.R` that derives `event_date` from the first ten timestamp characters and applies inclusive `from`/`to` bounds. Remove both backends' `sync_date` date filtering and route both collected results through the helper. Drop Arrow's partition-only `sync_date` column before returning so the documented eight-column schema is preserved.

- [x] **Step 4: Run focused and full local verification**

Run the focused test, `devtools::test()`, `devtools::document()`, and `devtools::check(error_on = "warning")`. Expected: focused test passes; full package verification has no errors or warnings.

- [x] **Step 5: Record and remotely validate the fix**

Add a concise `NEWS.md` bug-fix entry, commit the isolated branch, push it, and run the stress-test changelog surface against that package ref. The real-data CL-14 gate was blocked by pre-existing stress-harness bootstrap failures, so validate the same late-arriving-event regression directly on remote Ubuntu/Arrow. Expected: the remote assertion returns only the in-range event without introducing unexplained regressions.
