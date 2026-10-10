# TODO: Codex review fixes

Plan: [PLAN-codex-review-fixes-2026-10-09.md](PLAN-codex-review-fixes-2026-10-09.md). Tick a box only with evidence (command and counts) in the PR.

## Gate

- [x] Author approves the plan and answers D1 to D4 (all four recommendations are the defaults)
- [x] T0: author says "make the branch"; `feature/codex-review-fixes` exists

## F1: lavaan labels override roles

- [x] T1: reserved labels and precedence read from medfit (read-only)
- [x] T2: failing test (`a` on a covariate path)
- [x] T3: roles decide (medfit labels switched off) and `.check_lavaan_alias_labels()` rejects the conflict
- [x] T4: `run()` cross-check against `parTable()` plus planted-defect test

## F2: weighted MI fits and MBCO

- [x] T5: failing test (`weights`, `offset` in `fit_args`)
- [x] T6: `infer(type = "mbco")` refuses; `control` still allowed

## Ship

- [x] T7: docs, NEWS, comment and spec wording
- [x] T8: end-to-end transcripts (both reproductions plus a passing control)
- [x] T9: full suite 1547 / 0 / 8 (baseline 1523 plus 24 new); PR to `dev` opened
- [ ] T10: memory `mbco-glm-refits-ignore-fit-args` updated after merge

## Then

- [ ] Add F1 and F2 to the CRAN plan's T1 scope table
