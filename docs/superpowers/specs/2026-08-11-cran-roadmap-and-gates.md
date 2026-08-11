# tidybrreg 0.5.0 CRAN Roadmap and Evidence Gates

**Status:** Approved on 2026-08-11

**Target:** A public, CRAN-ready R package for reliable current access to BRREG. Historical persistence, managed state, replay, panels, networks, survival analysis, and harmonisation are outside 0.5.0.

**Baseline:** `tidybrreg` commit `c9bd99233fd9dc14fb5fefa8a878b1ae8fbd2857`; `tidybrreg-stresstest` commit `9e07c5eea2046189ea2431455cf01dbea0c73b74`.

## Product boundary

The package delivers two high-level journeys and retains endpoint-level primitives where they remain useful and coherent.

### Context-rich search

```r
brreg("DNB")
brreg(municipality_code = "4601")
```

The result supplies organization matches, establishment matches, batch-resolved parent entities, match links, and query metadata. It must preserve match provenance and make completeness observable.

The search contract is:

- Search entities and establishments without selecting one organization from ambiguous text.
- Resolve establishment parents with the empirically supported batched `organisasjonsnummer` query.
- Do not retrieve roles, group structures, signatur, or prokura for every match.
- Do not infer ownership from roles or name similarity.
- Do not partition a query automatically.
- Return a complete result within an empirically established endpoint limit or raise a typed, informative error before returning a partial population.

### Scalar entity dossier

```r
brreg_enrich("984851006")
```

The result supplies the entity or establishment, applicable relationships, and endpoint-level status. For a main entity, applicable calls include establishments, roles, reverse legal roles, group structure, signatur, and prokura. For an establishment, the result includes its parent and records main-entity-only endpoints as not applicable rather than calling them blindly.

The enrichment contract is:

- Accept one organization number in 0.5.0.
- Resolve entity versus establishment before fan-out.
- Use bounded concurrency only after its request-rate, failure, and CRAN implications are audited.
- Preserve partial endpoint failure and deletion status instead of collapsing every non-result to an indistinguishable empty tibble.
- Leave vectorisation and looping policy to a future separately reviewed feature.

### Bulk access

Bulk scope is limited to `enheter`, `underenheter`, and `roller` in gzipped JSON format. The public result is an in-memory tidy object. No persistent cache, snapshot, user-visible file, CSV parser, or Arrow result ships in 0.5.0.

Whether a session `tempfile()` is used internally is deliberately unresolved. Milestone 5 must measure compressed transfer size, peak memory, parse time, cleanup after success and error, and installed-package behavior before selecting an implementation.

### CDC and endpoint primitives

All three official update feeds (`enheter`, `underenheter`, and `roller`) remain in the focused client. Existing endpoint wrappers remain candidates for retention, but the final export list is not fixed by the obsolete 15-export contract. Every retained export requires its own contract review before implementation or removal.

### Removed release surface

The 0.5.0 source package and tarball exclude managed snapshots, manifests, sync state, replay, changelogs, historical readers, panels, events, flows, time series, networks, survival data, municipality/NACE harmonisation, CSV, Arrow, and Parquet-backed output. Git history at `c9bd992` remains the recovery point; no compatibility or deprecation layer is required because the package has not been released on CRAN.

## Decisions still gated

The following are implementation decisions, not implied by the approved product scope:

- Final export list and whether low-level names are consolidated.
- Exact S3 classes, component names, print methods, attributes, and typed-empty schemas for `brreg()` and `brreg_enrich()`.
- Whether `brreg_update_fields()` remains public or becomes an argument to `brreg_updates()`.
- The public name and arguments for in-memory JSON bulk retrieval.
- Retry, backoff, timeout, rate-limit, and bounded-concurrency policies.
- Internal temporary-file versus streaming parser strategy.
- Label and dictionary network/cache behavior.
- Minimum R and dependency versions.

No issue may decide one of these by implementation convenience. Each passes the contract gate below first.

## Authority and best-practice hierarchy

Each contract and feature review records the highest applicable authority and does not use a lower-level convention to override it.

1. Current CRAN Repository Policy.
2. Writing R Extensions matching the R version used for build and check.
3. R Packages for the established roxygen2, testthat, dependency, documentation, and release workflow.
4. Official documentation for directly used R packages such as httr2, tibble, vctrs, cli, and testthat.
5. Directly comparable mature R API clients when a convention is empirical rather than formal.
6. Explicit tidybrreg project decisions where no applicable consensus exists.
7. Empirical BRREG behavior from direct HTTP probes and execution of the actual package.

BRREG documentation locates routes and stated contracts; it does not establish behavior. Every upstream claim used in a design decision must distinguish documentation, observed HTTP behavior, and actual package output.

## Contract review gate

Before feature code is written, its issue must contain a completed review with:

1. User problem and observable public behavior.
2. Current package commit and executed baseline output.
3. Sanitized direct HTTP request/response evidence, including date and relevant headers.
4. BRREG documentation comparison and every discrepancy.
5. Applicable R/CRAN requirements and established conventions.
6. At least one directly comparable package or an explicit statement that no useful comparator exists.
7. Proposed types, schemas, errors, warnings, messages, side effects, network calls, completeness rules, and resource bounds.
8. Alternatives considered and why they were rejected.
9. Every deviation from mandatory or established practice, with empirical justification, user consequence, testing consequence, and maintainer approval.
10. Source, loaded, installed, bundled, and checked states affected.
11. A failing behavioral test or, for metadata-only work, a failing static/check assertion.
12. Exact focused, full-suite, GCP, stress, and tarball verification commands.

An issue is not agent-ready until this review is complete and approved.

## Feature implementation gate

Each implementation follows this order:

1. Add the smallest failing public-behavior test and record the intended failure.
2. Make the smallest source change.
3. Regenerate roxygen-owned `man/` and `NAMESPACE`; never hand-edit generated files.
4. Review every generated diff and require a second regeneration to be clean.
5. Run focused tests, the affected file, and the complete deterministic suite in clean R processes.
6. Install into a disposable library and test through the installed namespace.
7. Build a source tarball and inspect its contents.
8. Run checks on that exact tarball, including dependency-minimal modes when dependencies change.
9. Repeat the contract/best-practice audit against implemented behavior.
10. Run the digest-pinned GCP integration and milestone-aware stress gate; store its evidence in GCS.

Live BRREG tests remain separate from CRAN checks. Network unavailability must fail gracefully for users and must be classified honestly in integration evidence; it must not be converted into a passing package assertion.

## Exact-artifact GCP and stress invariant

Every milestone closes against one package artifact:

```text
frozen package commit
  -> R CMD build in the recorded GCP R environment
  -> tidybrreg_VERSION.tar.gz + SHA-256
  -> install that exact tarball in the stress image
  -> execute the recorded stress-suite commit
  -> publish inputs, manifests, logs, results, and checksums to GCS
```

The evidence manifest records at least:

- package source commit and dirty status;
- tarball filename and SHA-256;
- package version and installed exports;
- stress-suite commit;
- base R image digest and stress image digest;
- R version, platform, locale, timezone, and installed dependency versions;
- milestone identifier and gate policy version;
- start/end timestamps and exact commands;
- worker exit statuses, check counts, failures, skips, uploads, and GCS destination;
- BRREG observation timestamps for live claims.

A floating r-universe install, a source-tree-only run, or a run lacking package identity cannot close a milestone.

## Stress-gate semantics

The stress suite is a defect detector and integration gate, not a proof of correctness and not a substitute for `R CMD check`.

For each milestone:

- Every check is classified as retained, excluded from 0.5.0, or assigned to a future milestone.
- Excluded checks do not gate the focused package and remain recoverable in git.
- Harness errors, incomplete workers, duplicate/missing check identities, publication failures, and unexpected skips always fail the gate.
- A failure assigned to the current or an earlier milestone fails the gate.
- A future-milestone failure is permitted only when explicitly classified before the run and is reported separately.
- At the CRAN-candidate milestone, the retained surface has zero known failures and zero unexplained or unexpected skips.

## Milestones

| Milestone | Deliverable | Closure gate |
|---|---|---|
| M0 Contract and evidence reset | Replace stale issue contracts; add `brreg()` and `brreg_enrich()` issues; pin exact package artifacts in the stress harness; add milestone-aware classifications and GCS manifests | Repaired harness installs the SHA-verified baseline tarball, rejects identity/gate/upload faults, and publishes a complete M0 run record |
| M1 Focused package extraction | Remove the excluded platform, generated documentation, tests, vignettes, startup behavior, and unused dependencies from the source package | Built tarball contains only the focused client; installed namespace and startup purity match the approved reviewed export contract |
| M2 Empirical endpoint foundation | Audit every retained route, including three CDC feeds; implement common typed conditions, dates/times, deleted/not-found behavior, and completeness rules | Package output, direct HTTP behavior, and documentation are reconciled endpoint by endpoint; GCP/stress gate passes all M0-M2 checks |
| M3 Context-rich search | Implement reviewed `brreg()` search mode with entity/establishment results, batch-resolved parents, match provenance, and complete-or-error behavior | DNB and comparison queries demonstrate correct linkage and limits without scalar fan-out or silent truncation |
| M4 Scalar dossier | Implement reviewed `brreg_enrich(org_nr)` with entity/establishment resolution and endpoint-level status | Main entity, establishment, deleted, unavailable, empty, and partially failing cases pass deterministic and live integration tests |
| M5 In-memory JSON bulk | Retrieve and parse `enheter`, `underenheter`, and `roller` JSON only, with no persistent or user-visible files | Real full payloads pass memory/time/cleanup budgets; peak-resource evidence justifies the internal parser strategy |
| M6 Package and documentation completion | Complete labels/dictionaries, bundled-data provenance, dependencies, README, vignettes, help, examples, NEWS, and maintainer metadata | Source, loaded, installed, bundled, lean-dependency, documentation, and GCP/stress evidence agree |
| M7 CRAN candidate | Freeze, build, inspect, and check the exact upload tarball on the required R/platform matrix | No errors/warnings, every note resolved or justified, retained stress surface clean, unchanged SHA-verified tarball handed to maintainer |

## Current repository conflicts to resolve in M0

- Issue #45 fixes an obsolete 15-export namespace and retains path-returning bulk behavior.
- Issue #44 derives its endpoint inventory from that stale export list.
- Issue #47 asserts the same stale namespace and does not require the GCP/stress evidence chain.
- `DESCRIPTION`, `NAMESPACE`, README, vignettes, tests, and package startup still describe or exercise the excluded platform.
- `tidybrreg-stresstest/install.R` and its Dockerfile install a floating r-universe build.
- The stress runner gates only unexplained regressions; known current defects, worker failure, upload failure, and skipped coverage can remain non-blocking.
- Open PR #49 changes an excluded changelog subsystem and is outside the 0.5.0 release path.

## Release claim boundary

No milestone pass implies CRAN readiness. Only M7 may make that claim, after `R CMD check --as-cran` succeeds on the exact built tarball with no errors or warnings and every note, platform exception, dependency result, live-service result, and remaining human submission step is reported.
