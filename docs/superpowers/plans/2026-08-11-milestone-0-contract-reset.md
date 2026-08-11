# Milestone 0 Contract Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace stale GitHub contracts with the approved 0.5.0 roadmap and make every later package decision pass an explicit R-package and best-practice review before coding.

**Architecture:** The approved roadmap is the governing specification. GitHub milestones order work, feature issues hold completed contract reviews, and a versioned review template makes deviations auditable. This plan changes planning artifacts and issue metadata only; it does not modify package code, generated documentation, or exported behavior.

**Tech Stack:** GitHub Issues and Milestones, Markdown, git, GitHub CLI or the connected GitHub API.

## Global Constraints

- Target repository: `sondreskarsten/tidybrreg` at baseline `c9bd99233fd9dc14fb5fefa8a878b1ae8fbd2857`.
- Treat the package as public and CRAN-targeted.
- Use `docs/superpowers/specs/2026-08-11-cran-roadmap-and-gates.md` as the approved product and gate authority.
- Do not modify `R/`, `tests/`, `man/`, `NAMESPACE`, `DESCRIPTION`, vignettes, README, or NEWS in this plan.
- Do not decide an unresolved implementation contract inside an issue rewrite; open and gate it.
- Keep open PR #49 outside the 0.5.0 path because it changes the excluded changelog subsystem.
- Preserve git history at `c9bd992` as the recovery point for removed platform functionality.
- Every GitHub write must be re-fetched and compared with the intended title, body, labels, milestone, and dependencies.

---

### Task 1: Establish the immutable planning baseline

**Files:**
- Read: `docs/superpowers/specs/2026-08-11-cran-roadmap-and-gates.md`
- Read: `DESCRIPTION`
- Read: `NAMESPACE`
- Read: `README.md`
- Read: `.Rbuildignore`

**Interfaces:**
- Consumes: package commit `c9bd99233fd9dc14fb5fefa8a878b1ae8fbd2857` and open issues #17-#49.
- Produces: a recorded baseline that later issue edits can be compared against.

- [ ] **Step 1: Verify repository identity and cleanliness**

Run:

```bash
git rev-parse HEAD
git status --short
git remote get-url origin
```

Expected: commit `c9bd99233fd9dc14fb5fefa8a878b1ae8fbd2857`, no package-source changes, and `sondreskarsten/tidybrreg` as origin.

- [ ] **Step 2: Record the current public and dependency surface**

Run:

```bash
sed -n '/^Imports:/,/^[A-Z][A-Za-z]*:/p' DESCRIPTION
sed -n '/^Suggests:/,/^[A-Z][A-Za-z]*:/p' DESCRIPTION
sed -n 's/^export(\(.*\))/\1/p' NAMESPACE | sort
```

Expected: 43 exports and the persistence/analytics suggestions still present. Save the output in the M0 issue comment; do not create a generated snapshot in the package.

- [ ] **Step 3: Verify the roadmap is excluded from the CRAN tarball**

Run:

```bash
grep -Fx '^docs$' .Rbuildignore
```

Expected: `^docs$`. If absent, stop; adding it would be a package build change outside this plan.

### Task 2: Add the contract and deviation review template

**Files:**
- Create: `docs/contracts/contract-review-template.md`

**Interfaces:**
- Consumes: authority hierarchy and gates from the approved roadmap.
- Produces: the mandatory content copied into every contract or feature issue before it becomes agent-ready.

- [ ] **Step 1: Add a static assertion that the template does not yet exist**

Run:

```bash
test ! -e docs/contracts/contract-review-template.md
```

Expected: exit 0.

- [ ] **Step 2: Create the template with `apply_patch`**

Create exactly these headings:

```markdown
# Contract review: <public behavior>

## Decision status

- Proposed by:
- Reviewed by:
- Approved by:
- Package commit:
- Stress-suite commit:
- Review date:

## User problem and observable contract

## Executed package baseline

## Direct upstream evidence

## BRREG documentation comparison

## Applicable mandatory requirements

## Established R practice and comparators

## Proposed types, schema, and conditions

## Network, completeness, and resource bounds

## Side effects and package-state effects

## Alternatives considered

## Deviations requiring approval

| Reference practice | Chosen deviation | Empirical justification | User consequence | Test consequence | Approval |
|---|---|---|---|---|---|

## Failing test or static assertion

## Verification matrix

| State | Command | Expected evidence |
|---|---|---|
| Source |  |  |
| Loaded |  |  |
| Installed |  |  |
| Bundled |  |  |
| Checked |  |  |
| GCP/stress |  |  |

## Unavailable evidence and blockers
```

The angle-bracket text is an instruction in the reusable template, not an unresolved item in this implementation plan.

- [ ] **Step 3: Assert all mandatory sections are present**

Run:

```bash
for heading in \
  'User problem and observable contract' \
  'Executed package baseline' \
  'Direct upstream evidence' \
  'Applicable mandatory requirements' \
  'Established R practice and comparators' \
  'Deviations requiring approval' \
  'Failing test or static assertion' \
  'Verification matrix'; do
  grep -Fq "## ${heading}" docs/contracts/contract-review-template.md || exit 1
done
```

Expected: exit 0.

- [ ] **Step 4: Commit the template**

```bash
git add docs/contracts/contract-review-template.md
git commit -m "docs: add contract and deviation review gate"
```

### Task 3: Create the cross-repository M0 tracking issues

**Files:**
- Read: `docs/superpowers/specs/2026-08-11-cran-roadmap-and-gates.md`
- External write: GitHub issue in `sondreskarsten/tidybrreg`
- External write: GitHub issue in `sondreskarsten/tidybrreg-stresstest`

**Interfaces:**
- Consumes: the approved M0 deliverable and the separate stress-harness plan.
- Produces: one package-governance issue and one harness issue linked in both directions.

- [ ] **Step 1: Create the package M0 issue**

Use this title:

```text
M0: reset the 0.5.0 contracts and evidence gates
```

The body must link the approved roadmap file and require all of these acceptance criteria:

```markdown
- [ ] Issues #44, #45, and #47 no longer assert the obsolete 15-export/path-returning contract.
- [ ] Dedicated reviewed issues exist for `brreg()`, `brreg_enrich()`, and JSON-only in-memory bulk access.
- [ ] Every current release-blocker is assigned to exactly one M0-M7 milestone or split where its work spans milestones.
- [ ] The contract-review template is committed and referenced by every agent-ready feature issue.
- [ ] The linked stress-harness M0 issue installs and records an exact SHA-verified package tarball.
- [ ] A complete M0 gate run is published to GCS and linked here.
```

Apply labels `release-blocker` and `scope:core`.

- [ ] **Step 2: Create the stress-harness M0 issue**

Use this title in `sondreskarsten/tidybrreg-stresstest`:

```text
M0: pin the exact tidybrreg tarball and enforce milestone gates
```

Its body must link this package M0 issue and `docs/superpowers/plans/2026-08-11-milestone-0-exact-artifact-gate.md` in the stress repository. Its acceptance criteria are the acceptance criteria from that plan, without weakening them.

- [ ] **Step 3: Link both issues bidirectionally**

Add one comment to each issue containing the canonical URL of the other. Do not rely only on a title mention.

- [ ] **Step 4: Re-fetch both issues**

Expected: exact titles, open state, linked URLs, acceptance criteria, and no `agent-ready` label before the plans themselves are approved for execution.

### Task 4: Replace the stale core, endpoint-audit, and release-candidate contracts

**Files:**
- External write: tidybrreg issues #44, #45, and #47

**Interfaces:**
- Consumes: approved roadmap and the new package M0 issue.
- Produces: milestone-specific issues that no longer encode superseded behavior.

- [ ] **Step 1: Rewrite issue #45 as focused package extraction**

Set the title to:

```text
M1: extract the focused CRAN client from the current package
```

Replace the fixed 15-export assertion with these rules:

```markdown
- Remove the approved excluded platform from source, tests, generated documentation, vignettes, startup behavior, README, NEWS, and dependencies.
- Preserve candidate endpoint primitives until their contract reviews approve retention, consolidation, or removal.
- Do not implement `brreg()`, `brreg_enrich()`, or the new bulk contract in M1.
- Assert the installed exports against the public-API contract approved in M0; do not encode an export count in this issue before that review closes.
- Inspect the exact built tarball and retain `c9bd992` as the recovery point.
```

Remove statements retaining `path` output and forbidding all new exports. Keep `release-blocker` and `scope:core`; remove `agent-ready` until the M0 public-API review is approved.

- [ ] **Step 2: Rewrite issue #44 as the M2 empirical endpoint inventory**

Remove its dependency on “exactly the 15 exports.” Its inventory must include every route needed by:

```text
candidate endpoint primitives
brreg() context-rich search
brreg_enrich() scalar dossier
enheter, underenheter, and roller CDC
enheter, underenheter, and roller JSON bulk retrieval
retained label/dictionary behavior
```

Keep its existing requirements to test each endpoint independently, separate observed from documented limits, and avoid automatic partitioning. Add direct package-output comparison and a required contract-review artifact per endpoint family.

- [ ] **Step 3: Rewrite issue #47 as the M7 exact-candidate gate**

Remove the 15-export and path/tibble assertions. Require instead:

```markdown
- installed exports exactly equal the final approved public-API contract;
- the exact SHA-256 tarball is built and checked unchanged;
- ordinary, depends-only, and suggests-only checks are run in clean libraries;
- platform evidence and live integration evidence are reported separately;
- the digest-pinned GCP/stress run installs the same tarball and has zero retained-surface failures or unexpected skips;
- the complete manifest, logs, results, and checksums are stored in GCS;
- no CRAN submission, tag, or release occurs without a separate maintainer action.
```

- [ ] **Step 4: Re-fetch #44, #45, and #47 and run stale-contract searches**

Expected: no body contains `exactly the 15`, `fixed 15`, or a requirement that bulk output retain `path`.

### Task 5: Create the unresolved public-contract reviews

**Files:**
- External write: new tidybrreg GitHub issues
- Read: `docs/contracts/contract-review-template.md`

**Interfaces:**
- Consumes: approved product behavior and unresolved-decision list.
- Produces: separate approval gates for namespace, search, enrichment, and bulk behavior.

- [ ] **Step 1: Create the M0 public-API review issue**

Title:

```text
M0 contract review: final public API and namespace evolution
```

Require an export-by-export table with columns `current_export`, `0.5.0_disposition`, `replacement`, `owning_milestone`, `empirical_evidence`, `practice_review`, and `approval`. State explicitly that M1 is blocked until this issue is approved.

- [ ] **Step 2: Create the M3 search issue**

Title:

```text
M3: implement context-rich brreg() search
```

Copy the context-rich search contract from the approved roadmap. Require executed DNB and comparison baselines, typed limit conditions, parent-resolution provenance, no candidate dossier fan-out, and source/installed/tarball/GCP/stress verification.

- [ ] **Step 3: Create the M4 enrichment issue**

Title:

```text
M4: implement scalar brreg_enrich() dossiers
```

Copy the scalar dossier contract from the approved roadmap. Require separate main-entity, establishment, deleted, unavailable, empty, and partial-failure cases; endpoint-level statuses; bounded-concurrency review; and no vectorised public contract in 0.5.0.

- [ ] **Step 4: Create the M5 bulk issue**

Title:

```text
M5: implement JSON-only in-memory bulk retrieval
```

Fix public scope to `enheter`, `underenheter`, and `roller` JSON, returning in-memory tidy objects with no persistent or user-visible files. Keep internal `tempfile()` versus streaming unresolved until measured. Require full real-payload memory, time, cleanup, schema, and installed-package evidence before approval.

- [ ] **Step 5: Re-fetch all four issues**

Expected: each contains the complete contract-review headings or links the template and is labeled `blocked` rather than `agent-ready` until its review is approved.

### Task 6: Create and populate M0-M7 milestones

**Files:**
- External write: GitHub milestones and issue assignments

**Interfaces:**
- Consumes: milestone definitions in the approved roadmap.
- Produces: one unambiguous owning milestone for every release-blocking issue.

- [ ] **Step 1: Rename the existing `0.5.0 CRAN core` milestone to `M7 CRAN candidate`**

Preserve its issue history. Do not close it.

- [ ] **Step 2: Create milestones `M0 Contract and evidence reset` through `M6 Package completion`**

Use the deliverable and closure-gate text from the roadmap as each milestone description.

- [ ] **Step 3: Assign current issues**

Use this owning map:

| Milestone | Issues |
|---|---|
| M0 | new M0 roadmap issue; new public-API review issue |
| M1 | #22, #42, #45 |
| M2 | #19, #27, #34, #35, #43, #44 |
| M3 | new `brreg()` issue |
| M4 | new `brreg_enrich()` issue |
| M5 | #21, #36, new JSON bulk issue |
| M6 | #17, #18, #37, #46 |
| M7 | #47 |

Issue #48 is an automated drift report, not roadmap work; triage its concrete findings into the relevant endpoint issue and leave it without a release milestone. PR #2 and PR #49 remain outside the release path pending separate closure decisions.

- [ ] **Step 4: Add cross-milestone dependencies in issue bodies**

At minimum: M1 is blocked by the M0 public-API review and stress M0 issue; M2 is blocked by M1; M3 and M4 are blocked by M2; M5 is blocked by M1 and relevant M2 parser contracts; M6 is blocked by M3-M5; M7 is blocked by every open release-blocker.

- [ ] **Step 5: Audit assignment completeness**

Run a GitHub issue query and verify every open issue labeled `release-blocker` has exactly one M0-M7 milestone. An issue spanning milestones must be split, not assigned twice conceptually.

### Task 7: Verify and commit the planning reset

**Files:**
- Verify: `docs/superpowers/specs/2026-08-11-cran-roadmap-and-gates.md`
- Verify: `docs/superpowers/plans/2026-08-11-milestone-0-contract-reset.md`
- Verify: `docs/contracts/contract-review-template.md`

**Interfaces:**
- Consumes: all completed M0 planning tasks.
- Produces: a reviewable planning commit and a GitHub state ready for explicit execution approval.

- [ ] **Step 1: Confirm no package implementation file changed**

Run:

```bash
git diff --name-only HEAD~1..HEAD -- R tests man vignettes DESCRIPTION NAMESPACE README.md README.Rmd NEWS.md
```

Expected: no output.

- [ ] **Step 2: Scan planning artifacts for forbidden placeholders**

Run:

```bash
rg -n '\b(T[B]D|T[O]DO|implement[[:space:]]later|fill[[:space:]]in[[:space:]]details)\b' \
  docs/contracts docs/superpowers
```

Expected: no output.

- [ ] **Step 3: Re-fetch all changed and created issues**

Expected: titles, bodies, labels, milestones, blocking links, and agent-ready status match Tasks 3-6 exactly.

- [ ] **Step 4: Commit the roadmap and plan if they are not already committed**

```bash
git add docs/superpowers/specs/2026-08-11-cran-roadmap-and-gates.md \
  docs/superpowers/plans/2026-08-11-milestone-0-contract-reset.md
git commit -m "docs: define CRAN roadmap and milestone gates"
```

- [ ] **Step 5: Report the M0 execution boundary**

State explicitly that package feature work remains blocked. The first executable code task is the separately reviewed stress-harness exact-artifact plan; M1 package extraction starts only after the public-API review is approved and the M0 GCP/GCS stress gate passes.
