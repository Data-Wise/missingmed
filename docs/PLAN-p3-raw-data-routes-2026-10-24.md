# PLAN: close P3 with row-level stored data (2026-10-24)

Status: HISTORICAL. Superseded 2026-10-26 by author ruling B (simulated seed 45 qualifies; collaborator route, R3 and R5 dropped); see `tasks/plan.md` P3. Original status: draft for review. Nothing executed. Context: `tasks/plan.md` P3; leads in
`docs/PROPOSAL-p3-stored-improper-null-leads-2026-10-24.md`.

## Goal

One pre-existing stored dataset and mediation-shaped model, with provenance, whose **null**
fit (a = 0 or b = 0) is improper under medfit, with diagnostics naming the branch. No
generated, seeded or retuned data. The input must be row-level, because `medfit::fit_sem()` and
`mbco_sem()` take only `data` (no `sample.cov`; checked 0.7.0, 0.12.0, 0.13.0).

## Settled by the author (2026-10-24)

- Path A (spec unamended). A seeded simulator call does not qualify.
- A published covariance matrix counts as stored input, but cannot enter medfit, so it is evidence only.
- Roth (Kline Ch 9) as published: all nulls proper. Closed. Sabatelli (Kline Ch 14): full-model CFA Heywood
  case (intimacy error variance -39.892), not a null. Not usable without an added structural path (not authorized).

## Routes (ordered by cost; each ends at a go/no-go)

| # | Route | Output | Stop condition |
|---|---|---|---|
| R2 (first) | Check named sources already located: `~/Dropbox/Book/SEM/` (Chen and Yung 2023, Kline companion files, Bollen and Curran 2006, Loehlin and Beaujean 2017, Bollen 1989) for shipped row-level data files with a mediation-shaped model. Chen and Yung shipping data is an **unverified lead**; Kline Ch 17 is a guess | Candidate datasets with model specs as published | No mediation-shaped model, or no data file |
| R1 | Row-level data files near SEM material, only if R2 names a concrete new lead (tasks/plan.md forbids repeating broad fixture discovery without one) | Candidate files with paths | No concrete lead, or zero hits |
| R3 | Public replication data (OSF, Dataverse) for latent-mediator studies that report a Heywood case. Needs download approval per file (name, source, size) | Candidate with URL, version, hash | None found in a bounded search (5 queries) |
| R4 | Ask collaborators (draft only; the author sends) | Draft message | Author declines |
| R5 | Author's own project data with a known negative variance | Pointer from the author | None exists |

## Gate per candidate (every route)

1. **Origin.** Data must be empirical or collected, with a citation to the collection. Anything generated,
   seeded, or a stored copy of simulator output is nonqualifying (the `sem_model_heywood()` class). The file
   and its source version must predate this search (record mtime and source version/commit date).
2. **Record before fitting:** source, citation, license, sha256; keep the file outside the repo unless the
   author approves vendoring.
3. **Mediation-shaped as published.** The published model must already contain an identifiable X -> M -> Y
   (observed or latent) with paths a and b. Otherwise record "no mediation model, not screened". No path is
   added without a written author ruling before any fit (the Sabatelli class).
4. **Prespecified settings, one fit per candidate.** Estimator, missing-data handling, subset and variable
   coding come from the publication and are written to the proposal file, with the model spec and its hash,
   before the first fit. A hit under non-published settings is nonqualifying. Record every candidate
   screened, negatives included.
5. **Read-only screen:** full, `a == 0`, `b == 0` through installed medfit (`fixed_x = FALSE`,
   `meanstructure = NULL`), fresh `Rscript --vanilla`; log kept outside the repo; hashes unchanged after.
   Record per fit whether it is proper.
6. **Classify the hit.** Full proper and a null improper, branch named = candidate. Full model already
   improper = nonqualifying Sabatelli class unless the author rules otherwise. A one-branch hit (e.g. b-null
   improper, a-null proper) is accepted as one case; the injected controls and T5's all-scenarios conclusion
   are unchanged.
7. A candidate only. Full P3 checks (branch diagnostics, fallback refit settings, LR agreement) need a
   separate authorization.

## Out of scope

Generating rows from a matrix; retuning a dataset; adding covariance input to medfit; pushing or merging
anything; touching `tasks/plan.md` T5 wording before a real candidate exists.

## Stop-loss

If R2 (and R1, when it has a lead) yield nothing, ask the author to rule on R3 to R5 or on reframing the gate
(recommended against). R3 to R5 are author-gated and never start automatically. No further local searching.
R4 may be drafted in parallel with R2 (draft only; the author sends; no download needed).

## Evidence for the premise

"`fit_sem()` takes only `data`": checked by `formals()` on installed medfit 0.7.0 and on scratch builds of
0.12.0 (D4 head) and 0.13.0 (`origin/dev`), 2026-10-24; the check is a signature read, not a source audit. The
row-level requirement follows from it and narrows P3 to row-level data (a published covariance matrix is
evidence only).

## Checkpoints

- After R2: report counts and candidates; ask before any download (R3).
- After any hit: ask before the full P3 checks.
- Canonical record: `tasks/plan.md` P3 states the outcome; the proposal file holds the screen detail; other
  surfaces point to them (no triplication). Commits happen only on explicit request, local, not pushed.
- This plan file is untracked until the author asks for a commit.
