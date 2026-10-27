# BRAINSTORM: unblock P3 (stored improper-null input) — 2026-10-26

Depth: default. Focus: feat/ops. Context: PR #102 merged to `dev` (`9f77220`); T5 and D5 are follow-up gates.
Canonical record: `tasks/plan.md` P3; route plan: `docs/PLAN-p3-raw-data-routes-2026-10-24.md`. This file adds
no new evidence; it ranks the existing routes and records the 2026-10-26 author answers.

## Author answers (2026-10-26)

- Authorized: **R2** (read-only check of `~/Dropbox/Book/SEM/`) and a **draft-only R4** message.
- Not authorized: R3 (public downloads), R5 (author project data).
- Fallback if nothing qualifies: stop searching and **ask the author for a ruling**; do not reframe the gate.

## Quick Wins (< 30 min)

1. **R2 screen of named Dropbox sources** — only route that can end the gate without any new approval.
   Candidates: Chen and Yung 2023, Kline companion files, Bollen and Curran 2006, Loehlin and Beaujean 2017,
   Bollen 1989. Chen and Yung shipping data is an *unverified lead*; Kline Ch 17 is a guess.
2. **Draft R4 message** — one short ask to collaborators for a stored dataset with a known negative variance
   in an X -> M -> Y model. Draft only; the author sends.

## Medium Effort (1-2 hrs)

- [ ] If R2 names a hit: write the prespecified-settings block (estimator, subset, coding, model hash) into the
  proposal file **before** the first fit, then one read-only screen (full, `a == 0`, `b == 0`; fresh
  `Rscript --vanilla`; hashes unchanged).
- [ ] If R2 names a concrete new file lead: R1 near-SEM-material search (plan forbids broad repeats without one).

## Long-term (future sessions)

- [ ] R3 public replication data (5-query bounded search; per-file download approval) — only on author go.
- [ ] R5 author project data — only if the author points to one.
- [ ] Full P3 checks on any candidate (branch diagnostics, fallback refit settings, LR agreement) need a
  separate authorization.

## Risks / watch-outs

- Gate per candidate: origin must be empirical; seeded or simulator output is nonqualifying
  (`sem_model_heywood()` class). Record sha256, source, license before fitting; one fit per candidate.
- Full model already improper = Sabatelli class (nonqualifying unless ruled otherwise).
- A published covariance matrix is evidence only: `fit_sem()`/`mbco_sem()` take `data` only.
- `dev` already carries the merge, so a T5 that never closes is a standing gap, not a PR blocker; the stop-loss
  keeps the search bounded.

## Test plan (docs-tier)

Read-only screen; the check is a record, not a test suite. Evidence = candidate table (counts, paths, hashes),
fit log kept outside the repo, hashes unchanged after. Negatives are recorded too.

## Docs touched on a hit

`docs/PROPOSAL-p3-stored-improper-null-leads-2026-10-24.md` (screen detail) and the P3 paragraph in
`tasks/plan.md` (outcome only). `.STATUS` points to them; no triplication.

## Recommended Next Step

→ Run R2 first: it is authorized, free, read-only, and its output decides whether R1 or a ruling request is next.
