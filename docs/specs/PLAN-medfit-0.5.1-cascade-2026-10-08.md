# PLAN: medfit 0.5.1 release and cascade (GitHub-only)

| | |
|---|---|
| **Status** | Phase 0 done; Phase 1 planned, not started |
| **Date** | 2026-10-08 |
| **Decision** | GitHub-only release (author, 2026-10-08); CRAN is a separate later decision |
| **Repo written to** | `Data-Wise/medfit` (cross-repo: every write needs per-instance permission) |
| **Harness** | [medfit-0.5.1-gates.sh](medfit-0.5.1-gates.sh) (read-only, `pre` and `post`) |

## Overview

medfit `dev` carries one code fix not in 0.5.0 (#85: lavaan weighted `nobs` rounding),
one CI fix (#86), and 11 planning-doc commits. CRAN has 0.3.2; 0.5.0 was GitHub-only.
Release 0.5.1 so missingmed's `.lav_round_nobs()` workaround has an upstream fix to name.
No dependent needs code changes.

## Architecture decisions

- **GitHub-only:** no CRAN submission. missingmed keeps `.lav_round_nobs()` (it cannot require a non-CRAN medfit).
- **Patch bump, not minor:** the only code change is a bug fix; the planning docs ship as-is.
- **NEWS:** the #85 bullet currently sits under `# medfit 0.5.0` (dev NEWS.md line 89). It moves to a new `# medfit 0.5.1` section, because 0.5.0 is already tagged.
- **Release shape:** `chore/release-0.5.1` → `dev` (squash), then `dev → main` (merge commit), tag, GitHub release.

## Task list

### Phase 0: revdep workflow (done 2026-10-08)
- [x] T0.1 Diagnose weekly failure (`any::revdepcheck` not on CRAN)
- [x] T0.2 Fix install and false-failure detection, PR #86 merged (`eeacf4b`), run 37866490392 green
- [x] T0.3 Close false-alarm issue #87

### Phase 1: medfit release 0.5.1
- [ ] **T1.1 Release-prep PR** (`chore/release-0.5.1` → `dev`, S)
  - Accept: `Version: 0.5.1`, `Date` updated; NEWS `# medfit 0.5.1` holds the #85 bullet; 0.5.0 section no longer does; `.STATUS` updated.
  - Verify: `medfit-0.5.1-gates.sh pre` all PASS; `R CMD check --as-cran` 0 errors/0 warnings on the branch; full suite counts recorded.
  - Depends: none
- [ ] **T1.2 Merge T1.1** to `dev` (squash) after CI green
  - Verify: CI green on `dev` head; gates `pre` PASS
  - Depends: T1.1
- [ ] **Checkpoint A:** gates `pre` pass, `dev` green, author approves the release PR
- [ ] **T1.3 Release PR** `dev → main` ("Release: v0.5.1", merge commit, no `--delete-branch`)
  - Verify: CI green on the PR; version-sync gate
  - Depends: T1.2
- [ ] **T1.4 Tag and release:** tag `v0.5.1` on the merge commit, GitHub release with the NEWS section as notes
  - Verify: gates `post` (tag, release not draft)
  - Depends: T1.3, CI green on `main`
- [ ] **T1.5 r-universe:** confirm 0.5.1 served (can lag ~96 min)
  - Verify: gates `post` "r-universe serves 0.5.1"
- [ ] **Checkpoint B:** `medfit-0.5.1-gates.sh post` prints ALL GATES PASS

### Phase 2: dependents (check only; one session each)
- [x] T2.1 probmed: suite against medfit 0.5.1 (floor ≥ 0.3.0)
- [x] T2.2 medsim: suite against 0.5.1 (floor ≥ 0.2.0)
- [x] T2.3 RMediation: suite against 0.5.1
- [x] T2.4 mediationverse: suite against 0.5.1 (floor ≥ 0.2.0)
  - Audited read-only 2026-10-08 (no suites run): none of the four touches lavaan with sampling weights, so #85 does not affect them; CI green on `main` for all four (mediationverse's one 09-21 failure was a Windows 504 timeout). Remaining check after the release: CI green once 0.5.1 is on r-universe.
  - Note: probmed pins `Remotes: data-wise/medfit@v0.3.0`, so it never resolves 0.5.1; revisit at its next release.
  - Verify each: record command and pass/fail counts. Any failure: reproduce on medfit 0.5.0 before blaming 0.5.1.

### Phase 3: missingmed (deferred until medfit 0.5.1 is on CRAN)
- [x] T3.1 Add a comment to `.lav_round_nobs()` (`R/run.R`) naming medfit PR #85 and the 0.5.1 floor that makes it removable (done, `cf71018`)
- [ ] T3.2 When medfit ≥ 0.5.1 is on CRAN: raise the `medfit` floor in `DESCRIPTION`, delete `.lav_round_nobs()` and its test, run the IPW + lavaan test
- [ ] T3.3 Decide CRAN submission for medfit (separate decision; 0.3.2 → 0.5.x includes result-changing fixes #81, #82)

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| NEWS move leaves 0.5.0 inaccurate | Low | gate "0.5.0 section no longer holds it" |
| 11 planning commits ride the release | Low | docs only; `R CMD check` confirms nothing else changes |
| r-universe lag | Low | gate polls; do not retag |
| Cross-repo write authority | Medium | ask per action; plumbing/feature branch, never the other session's checkout |

## Open questions

- Should T1.1 also bump medfit's own docs mentioning 0.5.0 as current? (grep before the PR)
- CRAN for medfit: later, separate (T3.3).

## Current harness state (pre, 2026-10-08)

Before T1.1 the `pre` gates fail as designed on version and NEWS; the tag, test-file, `.9000`, revdep and CI gates pass.
