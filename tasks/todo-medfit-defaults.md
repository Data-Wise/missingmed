# Todo: medfit 0.14.0 default-change warning

See [plan-medfit-defaults.md](plan-medfit-defaults.md) (grilled 2026-10-24). Separate from `todo.md` (PR #102 T5 closure).

- [x] T0 — keep branch `keep/d3-pin-cba4c1a` created in the medfit checkout (local only).
- [ ] T1b — guard test: every `fit_sem(` in `R/mbco_sem.R` passes `fixed_x` and `meanstructure`; planted-defect check fails on the old form.
- [ ] Probe — can medfit `dev` 3a5c90a run the `infer(type = "mbco")` path? If not, T2 narrows to `.mm_sem_fit()` (fresh process per arm, match message text).
- [ ] Push — only after T1/T2 pass and the user approves; note other unpushed D4 commits ride along; then message `medfit-oct-23`.
- [ ] T1 — `meanstructure = NULL` at `R/mbco_sem.R:222` and `tests/testthat/test-mbco-sem-acceptance.R:360`; own commit; SEM MBCO tests pass on the **pinned** medfit with unchanged counts and fixture hashes; list as unreviewed/value-neutral in `plan.md`.
- [ ] T2 — two fresh `Rscript --vanilla` runs on medfit `dev` via `infer(type = "mbco")`: warning present with T1 reverted, absent with T1 applied; quote both transcripts.
- [ ] T3 — one `.STATUS` line; no NEWS bullet.
- [ ] Checkpoint A — lintr + SEM tests; say whether `R CMD check --as-cran` could run; human review before any push.
- [ ] T4 — read-only: does the lavaan MBCO path share medfit#320's product-null start behavior? File:line evidence; risk note for P3 only.
