# PROPOSAL: leads for P3, a stored improper-null input with provenance

Date: 2026-10-24. Status: brainstorm only; nothing executed, nothing written outside this file.
Context: T5 on PR #102 is BLOCKED until a pre-existing stored input/model reproduces an improper null without
generating or retuning data (`tasks/plan.md`, P3). The author ruled medfit's seeded `sem_model_heywood()`
nonqualifying. A bounded name/header search found no stored case.

## What the gate actually needs (from plan.md, P3 and the acceptance table)

1. Original data and model are stored and inspectable, with provenance. No generation, no retuning.
2. Under the existing medfit library, the *null* fit (a = 0 or b = 0) is improper (for example a negative variance)
   while the diagnostics still identify the affected branch (full / a / b).
3. Fallback refit settings and both raw LRs match the provider; saved inputs hash-identical before and after.
4. One case is accepted as one case; injected controls stay.

Why this is rare (hypothesis, unverified): with observed variables only, OLS-style path models almost never give an
improper variance. Improper solutions typically need a latent variable or a measurement model, so the candidate is
probably a latent-mediator model on small or noisy real data, where forcing a = 0 pushes a residual variance to the
boundary. Treat as a screening heuristic, not a fact.

## Screen result (2026-10-24, author-authorized, read-only): 0 candidates

Script: `docs/specs/p3-screen-2026-10-24.R` (writes nothing; hashes each dataset before and after). Run on medfit 0.12.0 (the
D4 head `3a98bf6`, installed in a scratch library) and medfit 0.13.0 (`origin/dev`), lavaan 0.7.3, fresh `Rscript --vanilla`.
Each case: the full model, then `a == 0` and `b == 0` nulls, `fixed_x = FALSE`, `meanstructure = NULL`.
Flag: `diagnostics$improper` non-empty, or a null-fit error.

| Case | n | Source | Result (both libraries) |
|---|---|---|---|
| PoliticalDemocracy (ind60 → dem60 → dem65, no residual covariances) | 75 | lavaan, Bollen 1989 | all 3 fits proper |
| HolzingerSwineford1939 (visual → textual → speed) | 301 | lavaan | all proper |
| HS1939, `school == Pasteur` | 156 | existing column | all proper |
| HS1939, `school == Grant-White` | 145 | existing column | all proper |
| jobs (treat → job_seek → depress2) | 899 | mediation (JOBS II) | all proper |
| framing (treat → emo → cong) | 265 | mediation | all proper |
| mediation_demo (treatment → mediator1 → outcome) | 400 | medfit | all proper |

Input hashes unchanged (12-hex prefixes: PD 86bd9936348c, HS 092ad2de65bb, Pasteur 80fe8cbdd358, Grant-White 3436bdd446ce,
jobs 8fd1cb6417df, framing 0a3261bf2548, demo 258fbe2d944c). Model choice is mine (simple screens, not tuned); the school
split uses an existing column and is declared, not retuned. A negative result here is weak evidence about the class:
these are models I picked, not an exhaustive search. Quick Wins 1 and 2 are therefore closed; Quick Win 3 and the Medium
items remain.

## Quick Wins (< 30 min each, read-only screening, each needs your go before any fit is run)

1. **Screen shipped real datasets with latent mediators** — lavaan 0.7.3 and psych 2.6.5 are installed. Candidates:
   `lavaan::PoliticalDemocracy` (ind60 → dem60 → dem65, Bollen 1989), `HolzingerSwineford1939` (mediation-shaped
   subsets), OpenMx's bundled datasets. Provenance is published and the data are stored, not generated. Fit full and
   both nulls through medfit; keep a candidate only if a null is improper. Cheapest honest test of the heuristic.
2. **Screen observed real mediation datasets** — `mediation` 4.5.1 (`jobs`, `framing`, `student`) and medfit's own
   `mediation_demo`. Low odds under the heuristic above, but the test is nearly free and rules a class out for good.
3. **Look inside the saved Missing Effect results** — `research/Missing Effect/simulation_results/` holds 20
   `truth_scenario_*.rds` and `pilot-comparators-2026-08-16.rds`. Check read-only what they store (data, fits or only
   summaries) and whether any dropped replication was an improper fit. Ruling needed: a dataset saved by an earlier
   simulation run is stored data, but it was seeded and generated once; you ruled a seeded call nonqualifying, so ask
   whether a saved artifact of an earlier run counts.

## Medium effort (1-2 hrs)

- [x] **CLOSED 2026-10-24, no lead:** Chen 2001 and Gerbing 1987 are both Monte Carlo studies (generated samples), not
  published datasets; see plan.md P3. Other literature (applied papers reporting a Heywood case with data) is still open.
- [ ] **Mine the improper-solution literature for published datasets.** `mbco-lrt` already has notes on Chen et al.
  (2001) and Gerbing and Anderson (1987). Check whether either published a dataset or covariance matrix with a
  Heywood case in a mediation-shaped model; a published covariance matrix is stored input with citable provenance.
  Needs the PDFs read, not the notes.
- [ ] **Search other labs' public replication data** (OSF/Dataverse) for latent-mediator studies that report a
  Heywood case or a negative variance, then record URL, version and hash before any use. Needs network access and
  your approval to download (downloads need explicit permission).
- [ ] **Ask collaborators.** A short, specific request: "a dataset and latent-mediator model where lavaan or Mplus gave
  a negative variance." People who run SEMs often have exactly one.

## Long-term (future sessions)

- [ ] **Own-data route:** if a real project of yours has such a case (dissertation or consulting data), store it with
  provenance notes and hashes in a fixtures location, then use it as the P3 input. Gated by data-sharing rules.
- [ ] **Reframe the gate (needs your ruling; I recommend against it):** accept a real stored input whose *full* fit is
  improper, plus the injected null controls. This weakens the author-added hold; plan.md says the hold is not
  waived or replaced.
- [ ] **Amend the spec (path B):** you confirmed path A today, so this stays off the table unless you reverse that.

## Options I am not recommending

- Seeded or generated data of any kind (ruled out). A "stored" copy of freshly generated data would be the same thing
  under a different filename.
- Retuning a real dataset until a null goes improper (P3 forbids retuning).

## Recommended next step

Start with Quick Win 1, in this order: screen `PoliticalDemocracy`, then `HolzingerSwineford1939`. Reason: both are
real, stored, citable, and shipped in an installed package, so they satisfy the provenance rule outright. If neither
produces an improper null, move to the literature datasets (Medium, first item).

Before any screen: it runs fits, and P3 verification needs your separate execution authorization. Screening should
hash each dataset first and write nothing back, and a hit is only a candidate until the full P3 checks pass.

Honest limit: I could not name a dataset I know to be improper in the null. The candidates above come from
"real latent-variable data exists locally" plus a heuristic, not from a known Heywood case.
