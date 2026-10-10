# PLAN: fix the two silent wrong-inference paths from the Codex adversarial review

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | APPROVED 2026-10-09 (D1 revised to "A": force role resolution, plus the alias-label refusal and the run() cross-check). T0 to T9 done; T10 after merge. |
| **Source** | Codex adversarial review of `main...dev` (job `bcyvxedf1`, 2026-10-09 21:54), triaged the same evening |
| **Checklist** | [TODO-codex-review-fixes-2026-10-09.md](TODO-codex-review-fixes-2026-10-09.md) |
| **Feeds** | [PLAN-cran-1.0.0-2026-10-09.md](PLAN-cran-1.0.0-2026-10-09.md) T1: both bugs belong before 1.0.0 |

## 1. The two findings

| # | Where | Silent failure | Status |
|---|---|---|---|
| F1 | `R/run.R:204-207` (lavaan branch) | `medfit::extract_mediation()` is called with role names only, so medfit's default labels `a`, `b`, `cp` win over the roles. With `M ~ am*X + a*C; Y ~ b*M + cp*X + C` (treatment X, mediator M) it returned `a = 0.906`, the C to M path; the X to M path `am` is 0.504. MC inference then targets a different indirect effect than MBCO. | **Reproduced** 2026-10-09 against the installed medfit (`$TMPDIR/f1.R`, scratch) |
| F2 | `R/infer.R:108-111`, `R/mbco_mi.R:94-95` | `infer(type = "mbco")` on the MI path drops `@fit_args`, and `.mm_glm_ll()` refits with bare `stats::glm()`. A `weights` entry in `fit_args` changes the fitted effect, while the MBCO p-value describes the unweighted model. Only the IPW path refuses. | Source-confirmed, **not run**; documented as a limit at `R/mbco_mi.R:73` and spec `SPEC-glm-mbco-calibration-2026-10-09.md` line 81, but nothing refuses or warns |

## 2. Decisions to settle first (recommendation first)

| # | Question | Recommendation | Rejected alternative |
|---|---|---|---|
| D1 | F1: reject conflicting labels at `set_md_mediation()`, or resolve by role rows? | **Reject at set time, and add a post-extraction cross-check in `run()`.** In-repo, small, and the error names the label and the fix. A medfit change needs your per-instance permission. | Resolve from the structural role rows: correct, but re-implements medfit's resolution in missingmed and drifts from it. |
| D2 | F2: refuse or pass through? | **Refuse**: `infer(type = "mbco")` errors when `fit_args` holds a likelihood-changing entry. Passing `weights` through changes the D4 df derivation and needs its own calibration. | Pass through now: ships an uncalibrated variant. |
| D3 | F2: which entries count as likelihood-changing? | `weights`, `offset`, `subset`, `na.action`. `control` and `start` change convergence only; they stay allowed and documented. To confirm in T3 against what `medfit::fit_mediation()` forwards. | Refuse every `fit_args` entry: breaks `control`, which users need for the convergence guard. |
| D4 | One PR or two? | **One PR, two commits** (F1, F2), because both are small and both gate 1.0.0. | Two PRs: more CI runs for the same release gate. |

## 3. Tasks

Branch `feature/codex-review-fixes` from `dev`. Tests first; each task leaves the suite green. Local tests use the scratch-copy method (lavaan floor lowered), run in the background.

| # | Task | Acceptance | Verify |
|---|---|---|---|
| T0 | Create the branch (author's go-ahead) | `git branch --show-current` shows it | the command |
| T1 | Read-only: list medfit's reserved lavaan labels and how `extract_mediation()` resolves them (`R/extract-lavaan.R`, installed version and `dev`) | the exact label set and the precedence rule are written in the PR body, with the medfit version | quotation with file and line |
| T2 | F1 test first: model with a user label that medfit reads as a role (`a` on a covariate path); both orders (`a` before and after the role path) | the test fails on the base: `run()` returns the C to M estimate | red run quoted |
| T3 | F1 fix: `.check_lavaan_spec()` errors when a reserved label sits on a parameter that is not the role path; error names the label, the parameter and the rename | T2 passes; models whose reserved label sits on the role path itself (`a*X`) still pass; existing `test-lavaan-spec.R` and `test-lavaan-run.R` unchanged | targeted tests plus full suite |
| T4 | F1 belt and braces: after extraction in `run()`, compare the extracted `a`, `b`, `c_prime` with the `parTable()` estimates of the role rows; stop on a mismatch | a planted mismatch (stubbed extractor) is caught; a correct fit is not flagged | planted-defect test |
| T5 | F2 test first: `fit_args = list(weights = w)` on the MI path, nonconstant `w`; also `offset` | `infer(type = "mbco")` currently returns a p-value (red); `infer(type = "mc")` must keep working | red run quoted |
| T6 | F2 fix: refuse in `infer()` before `.mm_d4_mbco()`, message names the entry and says `mc` still works; `control` still passes | T5 passes; `test-fit-args.R` IPW refusals unchanged | targeted tests plus full suite |
| T7 | Docs: `?infer` and `?set_md_mediation` state both limits; `NEWS.md` bug-fix entries; the comment at `R/mbco_mi.R:73` points at the refusal; `SPEC-glm-mbco-calibration` line 81 says "refused" | `git grep` for each changed behavior finds no stale sentence; markdownlint at base counts | grep output in the PR |
| T8 | End-to-end evidence (per `e2e-before-pr.md`): one live run each of the two reproductions on the branch | transcript shows the error from F1 and from F2, and a correct control passes | quoted in the PR body |
| T9 | PR to `dev`: full suite counts against the dev baseline of 1523 passed, 0 failed, 8 skipped | counts in the PR body | CI plus local counts |
| T10 | After merge (author's step): update memory `mbco-glm-refits-ignore-fit-args` to "refused since <PR>" | the memory file matches the code | read the file |

## 4. Risks

| Risk | Mitigation |
|---|---|
| The label rule rejects a model users already run correctly | T3 acceptance keeps models whose reserved label is on the role path; the error text gives the rename |
| medfit changes its label precedence | T4's cross-check catches it at run time, whatever the rule is |
| `weights` also arrives through `mice` or a formula offset, not `fit_args` | out of scope; T7 states the refusal covers `fit_args` only |
| The Codex review ran no R code ("read-only temporary-file restrictions") | F1 is reproduced here; F2 is reproduced in T5 before any fix |

## 5. Out of scope

- Passing `weights` through the glm MBCO refits (needs a calibration, a separate item).
- Any change in medfit (read-only here; needs per-instance permission).
- The remaining 2 Codex notes: none; the review returned two findings.
