# NOTE: should `engine = "lavaan"` MBCO delegate to medfit's `mbco_sem()`?

| | |
|---|---|
| **Status** | PROPOSED, awaiting the author's ruling |
| **Date** | 2026-10-16 |
| **Answers** | `.STATUS` open item (1); medsim#62 task 3 |
| **Basis** | Read-only: medfit `origin/main` (0.10.0, 157a1db) `R/sem-mbco.R`, `R/fit-sem.R`, NEWS, the RMediation handoff in `planning/specs/`; missingmed `R/mbco_lavaan.R`, `R/run.R`, `SPEC-sem-mbco-2026-10-08.md`. **No parity run was made**: medfit 0.10.0 is not installed here (CRAN has 0.3.2), and installing it is out of scope for a read-only look. |

## Recommendation

**Do not delegate now. Keep the lavaan provider.** Revisit as an additive, opt-in route
only when the triggers in section 5 hold. The answer does not block medsim#62 task 2
(see section 4).

## 1. What each side does

| | missingmed `engine = "lavaan"` | medfit `mbco_sem()` |
|---|---|---|
| Fitter | `lavaan::sem()` per imputation; `run()` fits and pools with the same fitter | medfit's native `fit_sem()` (`SEMFit`) |
| Input | lavaan syntax + `fit_args`; the a and b rows are found as `M ~ X`, `Y ~ M` | one `SEMFit`; the user must label the two paths (`a*`, `b*`) |
| Null refits | `parTable()` of the fitted full model, one row fixed to 0 | refit with `<label> == 0` appended to the syntax |
| Statistic | per dataset the triple `(ll_full, ll_a, ll_b)` + `k_a`, `k_b`; the pooling is estimator-free (`.mm_d4_pool()`) | `min(diff_ll)`, df = 1, `htest`; `tests` holds one `diff_ll` per branch |
| Inference | D4 across imputations (stacked fit, `r4`, `ariv`, Chan-Meng df) | single dataset, chi-square(1) |
| Estimator | ML only (MLR refused, gate failed, PR #84) | ML |
| Missing data | none needed: imputed data are complete | complete cases only (rows with NA dropped) |
| Latent mediator | supported; `b = 0` fixes the structural path only (S3) | supported (`=~` in the syntax); the null is the labeled path |
| Boundary | not checked | warns when a bound or inequality is active at the null |
| Distribution | `lavaan` (CRAN) | medfit 0.10.0 **GitHub only**; CRAN has 0.3.2 |

## 2. Can `mbco_sem()` supply the provider contract?

Probably yes, which is the case for delegation. The D4 pooling uses differences of
log-likelihoods, and `tests$diff_ll = n * (f - fit@f)` equals `2 * (ll_full - ll_null)`
for each branch. A medfit-backed provider would return `full = 0`,
`a = -diff_a / 2`, `b = -diff_b / 2`, `k_a = k_b = 1`. **Unverified:** that
`.mm_d4_pool()` never uses an absolute log-likelihood, and that `mbco_sem()` agrees
with the lavaan triple to numerical precision on the T8a data (observed and latent).
Both are a small check, not done here.

## 3. Why not delegate now

1. **CRAN.** missingmed's CRAN path is already blocked on RMediation 1.7.1 and the medfit
   floor. A hard dependency on `mbco_sem()` needs a CRAN medfit that carries it
   (CRAN 0.3.2 does not). A Suggests-only route needs two code paths to keep in sync.
2. **No capability gain for MI.** The two reasons to use a native engine, FIML and a
   better-behaved nonlinear solve, do not apply: imputed data are complete, and the
   lavaan provider already solves two linear nulls, the same construction `mbco_sem()` uses.
3. **Fitter mismatch.** `run()` and `pool()` fit with lavaan and convert through
   `medfit::extract_mediation()`. Taking the MBCO nulls from a different fitter would make
   `infer(type = "mbco")` test a model other than the one `run()` fitted, unless the whole
   engine moves, which is a separate and larger decision.
4. **User surface.** `engine = "lavaan"` takes lavaan syntax and `fit_args`
   (`std.lv`, `fixed.x`, `orthogonal`, ...). `fit_sem()` has its own syntax and options;
   unlabeled paths are refused. Every difference is a new error message or a silent
   semantic change.
5. **Validation.** The lavaan provider carries the T8a calibration (size under D4, own and
   fixed `ariv`). `mbco_sem()` has a k-path size simulation for one dataset, not for D4
   under MI. Delegating re-opens that gate for no gain.

## 4. Effect on medsim#62

- **Task 2 (medsim delegates to `missingmed::mbco_d4()`)** is **not blocked**. It touches
  the plain data-frame (glm/OLS) path, and this note leaves `mbco_d4()` and `.mm_d4_pool()`
  unchanged. The issue text says to skip task 2 "if the coordination note moves SEM-MBCO
  elsewhere"; this note does not.
- The cross-package design stays: D4-MBCO under MI lives in missingmed; complete-data MBCO
  lives in medfit (`mbco_sem()`) and RMediation. This note takes no position on RMediation's
  route (its own handoff, G10, supersedes the path-label plan).

## 5. Triggers to revisit

Reopen when **all** hold:
1. A CRAN medfit carries `mbco_sem()` (or missingmed has decided to depend on a GitHub medfit).
2. A parity check passes: `mbco_sem()` `diff_ll` vs the lavaan triple differences to 1e-6,
   on the T8a observed and latent models, including a case where `a` and `b` branches
   disagree across imputations.
3. A use case exists that lavaan cannot serve (for example a model `fit_sem()` fits and
   lavaan cannot, or a constraint type only medfit supports).

Then the form is **additive**: a second provider behind an explicit engine option, with
the lavaan provider kept as the default, mirroring RMediation's additive route.

## 6. Cheap next step (if the author wants evidence before deciding)

Install medfit 0.10.0 into a scratch library (not the user library), run the parity check in
section 5(2) on the T8a data, and record the result here. About an hour; no repo changes.
