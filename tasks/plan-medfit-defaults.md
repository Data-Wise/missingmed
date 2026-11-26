# Plan: adapt to medfit 0.14.0 `fit_sem()` default-change warning

Separate from the PR #102 T5 gate documents (`plan.md`, `todo.md`), which stay untouched.
Source: [medfit#329](https://github.com/Data-Wise/medfit/issues/329) and medfit's comment on PR #102.
Status: **GRILLED 2026-10-24 (5 + 4 branches); REVIVED after medfit session confirmed the work is open.** No missingmed code changed yet.

medfit-oct-23 confirmed (origin/dev 3a5c90a): warning merged on dev; 0.14.0 NOT released (v0.13.0 latest); explicit
`fixed_x = FALSE, meanstructure = NULL` is the supported opt-out after 0.15.0; medfit's T10 waits on this fix landing on PR #102.

## Grill round 2 (decisions locked)

| # | Branch | Decision |
|---|---|---|
| 6 | Protect the D3 pin `cba4c1a` (valid medfit commit, on no branch, gc-able) | Local keep branch `keep/d3-pin-cba4c1a` in the medfit checkout, no push. **Done 2026-10-24.** |
| 7 | T2 if medfit `dev` can't run the full `infer(type = "mbco")` path | Narrow to `.mm_sem_fit()`, fresh `Rscript --vanilla` per arm, warning matched by message text; commit note says aggregated text is not covered. Supersedes #4's public-path requirement only in that case. |
| 8 | When to push | After T1/T2 pass, ask the user then. Pushing the branch also sends the other unpushed local D4 review commits; say so in the ask. No merge. Tell `medfit-oct-23` once pushed. |
| 9 | Regression guard | Add a small source-scan test: every `fit_sem(` call in `R/mbco_sem.R` passes `fixed_x` and `meanstructure`, with a planted-defect check that it fails on the old form. |

Pin note: use `keep/d3-pin-cba4c1a` for the T1 "unchanged counts" run; use medfit `dev` 3a5c90a for T2 (v0.13.0 has no warning; switch to the v0.14.0 tag once it exists).
Also checked: the mock in `tests/testthat/test-mbco-sem-args.R:62` only asserts `fixed_x`, so the extra argument cannot break it; no `dev/` script matches the call text.

## Grill ledger (decisions locked)

| # | Branch | Decision | Reason |
|---|---|---|---|
| 1 | Which medfit proves "no numeric change" | Pinned commit for T1, medfit `dev` for T2 | Receipts and fixture hashes were built on the pin; only `dev` can warn |
| 2 | When T1 lands | Now, own commit, listed as unreviewed + value-neutral in `plan.md` | medfit asked for it before PR #102 merges |
| 3 | meanstructure decision | **Deleted** (old T4/T5); recorded as spec-settled at `NULL` | Approved spec treats `meanstructure` as an ignored invariant; avoids reopening the T5 evidence gate |
| 4 | How T2 proves the warning is gone | Fresh `Rscript --vanilla` process per arm, via public `infer(type = "mbco")` | medfit warns once per session; same-session control can't fail; user-facing text is aggregated |
| 5 | Where T1 is recorded | Commit message + one `.STATUS` line; no NEWS bullet | No released user is affected |

Resolved by reading the code, not asked: the version floor is safe (`meanstructure` arrived in medfit 0.9.0; the runtime
guard at `R/mbco_sem.R:207` requires 0.10.0).

## Facts (verified 2026-10-24)

- medfit 0.14.0 (on medfit `dev`) warns once per session, class `medfit_warning_default_change`, when `fit_sem()` leaves
  `fixed_x` or `meanstructure` unset. Results unchanged in 0.14.0. 0.15.0 flips both defaults, no earlier than two months later.
- missingmed has exactly two unguarded calls: `R/mbco_sem.R:222` and `tests/testthat/test-mbco-sem-acceptance.R:360`.
  The refit at `R/mbco_sem.R:233` already passes both arguments.
- `meanstructure = NULL` is today's behavior and matches the refit rule at `R/mbco_sem.R:236`.
- Installed medfit is 0.7.0 (no `fixed_x`/`meanstructure` arguments). The SEM MBCO path only runs against a source-loaded medfit.

## Dependency graph

```text
T1 explicit meanstructure = NULL (code + test)
   ├─> T2 warning-absence proof (fresh processes, medfit dev)
   └─> T3 .STATUS line
T4 medfit#320 exposure check (independent, read-only)
```

## Tasks

### T1 — Pin today's behavior explicitly (S)

- `R/mbco_sem.R:222` becomes `medfit::fit_sem(model, d, fixed_x = FALSE, meanstructure = NULL)`.
- `tests/testthat/test-mbco-sem-acceptance.R:360` gains `meanstructure = NULL`.
- Acceptance: `grep -n "fit_sem(" R tests` shows no call without both arguments.
- Verify against the **pinned** medfit (source-loaded): SEM MBCO deterministic files pass with the same counts as the last
  receipt (1,584 assertions for the D4 files); fixture hashes unchanged; lint clean on changed lines.
- Own commit on `feature/lavaan-mbco-medfit`. Add it to `plan.md`'s unreviewed-late-edits list as value-neutral.
- No NEWS entry. Optional version-free comment at the call site.

### T2 — Prove the warning is gone (S)

- Two separate `Rscript --vanilla` processes (run from outside the repo, per the renv gotcha), each source-loading medfit
  `dev` (0.14.0) and calling `infer(type = "mbco")` on the lavaan T5 fixture with warnings captured.
- Arm A: T1 reverted. Must show `medfit_warning_default_change` (control that can fail).
- Arm B: T1 applied. Must show none, including none inside the aggregated "SEM MBCO warnings" text.
- Quote both transcripts in the commit note.

### T3 — Record it (XS)

- One `.STATUS` line only. No NEWS, no memory duplicate.

### Checkpoint A

- lintr plus SEM tests. State plainly whether `R CMD check --as-cran` could run with the installed medfit 0.7.0.
- Human review before anything is pushed. No push or merge in this plan.

### T4 — medfit#320 exposure check (S, read-only)

- Does the lavaan MBCO path share the product-null fit and start strategy that medfit#320 flags (lavaan LR above the medfit
  reference on about 30% of gate runs)? Written yes/no with file:line evidence.
- If yes: record as a risk for the P3 real-case gate. No code change.

## Risks

| Risk | Mitigation |
|---|---|
| Testing against 0.7.0 gives false "unused argument" errors | Always source-load; name the medfit used in every receipt |
| T1 lands inside code under D4/D5 review | Own commit; listed as unreviewed and value-neutral |
| Once-per-session warning spoils the control | Fresh process per arm |
| Pinned medfit lacks the warning | T2 uses `dev`; T1 equivalence uses the pin |
