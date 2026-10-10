# TODO: Codex review fixes

Plan: [PLAN-codex-review-fixes-2026-10-09.md](PLAN-codex-review-fixes-2026-10-09.md). Tick a box only with evidence (command and counts) in the PR.

## Gate

- [ ] Author approves the plan and answers D1 to D4 (all four recommendations are the defaults)
- [ ] T0: author says "make the branch"; `feature/codex-review-fixes` exists

## F1: lavaan labels override roles

- [ ] T1: reserved labels and precedence read from medfit (read-only)
- [ ] T2: failing test (`a` on a covariate path)
- [ ] T3: `.check_lavaan_spec()` rejects the conflict
- [ ] T4: `run()` cross-check against `parTable()` plus planted-defect test

## F2: weighted MI fits and MBCO

- [ ] T5: failing test (`weights`, `offset` in `fit_args`)
- [ ] T6: `infer(type = "mbco")` refuses; `control` still allowed

## Ship

- [ ] T7: docs, NEWS, comment and spec wording
- [ ] T8: end-to-end transcripts (both reproductions plus a passing control)
- [ ] T9: full suite vs baseline 1523 / 0 / 8; PR to `dev`
- [ ] T10: memory `mbco-glm-refits-ignore-fit-args` updated after merge

## Then

- [ ] Add F1 and F2 to the CRAN plan's T1 scope table
