# GRILL: SEM-MBCO spec

| | |
|---|---|
| **Target** | [SPEC-sem-mbco-2026-10-08.md](SPEC-sem-mbco-2026-10-08.md) |
| **Date** | 2026-10-08 |
| **Status** | Done: Q1-Q6 locked and folded into the spec |

## Evidence gathered (no question needed)

- Only the per-dataset log-likelihood triple and `k` are estimator-specific in `R/mbco_mi.R`; the D4 pooling is generic.
- [probe-sem-mbco-2026-10-08.R](probe-sem-mbco-2026-10-08.R): 10/10 checks pass. The constrained table must come from `parTable(<fitted full model>)`, not a bare `lavaanify()` (16 vs 14 free parameters on a latent model).
- `.check_lavaan_spec()` already requires `mediator ~ treatment` and `outcome ~ mediator` rows, so the constraint rows are unambiguous.

## Decision ledger

| # | Question | Decision | Recommended / rejected |
|---|---|---|---|
| Q1 (S3) | Meaning of `b = 0` with a latent mediator | **Structural path plus the indicator links**; df = 1 + the number of direct `Y ~ indicator` rows | Recommended (not chosen): structural path only. Rejected: remove the latent variable (not nested)**Superseded 2026-10-08 (adverse review): structural path only**, because fixing indicator links tests more than a·b = 0; see SPEC section 10. |
| Q2 (S4) | Estimators | **ML and MLR**; `MLM`, `WLSMV`, `ordered`, `group`, `sampling_weights`, IPW refused | Recommended (not chosen): ML only |
| Q3 (S6) | Improper null fit | **Warn once, proceed**, as G2 | Rejected: refuse (fragile at m >= 20) |
| Q4 (S7) | `mbco_d4()` | **Gains `model =`**, mutually exclusive with the formula arguments | Recommended (not chosen): formula-only |
| Q5 | Release shape | **Its own 0.8.0**; ML can ship first | Rejected: fold into 0.7.1; hold for medfit |
| Q6 | Validating MLR | **Experimental warning plus a medsim size gate** (5% level, empirical size 3.5-6.5%, m = 20, n = 200 and 500, non-normal, MAR); if it fails, MLR stays refused and gets its own spec | Rejected: ship without a gate; defer outright |

## Consequences of the non-recommended choices (recorded so they are not lost)

- Q1: a model with direct indicator-to-outcome paths is a different mediation model; the ruling treats the latent construct as the mediator and nulls its whole effect on the outcome. `k` is read from the fitted tables, so it is constant across imputations.
- Q2: D4 has no published form for the scaled MLR statistic. The gate is the safeguard; the risk is recorded in the spec.
- Q4: adds one exported signature to design, document and maintain (task T6).
