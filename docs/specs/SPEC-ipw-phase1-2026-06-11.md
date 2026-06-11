# SPEC — Phase 1: IPW (Inverse-Probability Weighting) Estimator

| | |
|---|---|
| **Status** | draft |
| **Created** | 2026-06-11 |
| **Author** | Davood Tofighi |
| **Parent scope spec** | `docs/specs/SPEC-missingmed-scope-2026-06-04.md` (Phase 1 of 6-phase roadmap) |
| **Prereq** | Phase 0 S7 migration on `feature/s7-migration` (complete; E0/W0/N0, 47 tests) |
| **Branch** | `feature/ipw-phase1` (to be created off `dev` when implementation begins) |

---

## 1. Goal

Add an **IPW estimator** to the `missingmed` S7 pipeline.  IPW is a robustness
complement to MI (see manuscript appendix): rather than filling in missing values,
it reweights the **observed complete cases** so they represent the full population
under MAR.  The estimator must slot into the existing `set_md_mediation() →
run() → pool() → infer()` chain without changing that interface — only `run()`
grows a new code path, and `pool()` becomes a thin passthrough.

**Non-goals (later phases):** MNAR IPW sensitivity (Phase 3), doubly robust
(DR-IPW) estimator, simulation harness (`medsim`, Phase 4), CRAN polish (Phase 5).

---

## 2. Background and rationale

Under MI, missing values are imputed `m` times; inference uses Rubin's rules to
pool `m` estimates.  Under IPW, the complete cases are upweighted to compensate
for those dropped, and inference is performed once on the weighted data.  The two
paths are **orthogonal axes** (`method = "mi"` vs `"ipw"`) already encoded in
`MDMediationData@method`.

Key asymmetry: MI loops over `m` imputed datasets → `pool()` is a non-trivial
Rubin's-rules step.  IPW produces a **single weighted fit** → `pool()` is an
identity-like passthrough (`m = 1`, between-imputation variance `B = 0`).

---

## 3. IPW pipeline walkthrough

```
set_md_mediation(data, model, method = "ipw",
                 weight_formula, weight_stabilize, weight_trim)
        ↓  (stores data.frame, missingness model spec)
   MDMediationData  (@method = "ipw")
        ↓  run()
   .ipw_run()          ← new internal function
     1. Identify complete cases (R = 1 indicator)
     2. Estimate P(R=1|Z) per incomplete variable (logistic GLM)
     3. Compute weights w_i = 1/P̂(R_i=1|Z_i)  [or stabilized]
     4. Trim weights at requested percentile (optional)
     5. fit_mediation(..., weights = w) on complete-case data  ← medfit
     6. Wrap as MDMediationFit(m=1, per_imputation=list(one named MediationData))
        ↓  pool()
   pool()            ← existing code, Rubin's rules with m=1 → B=0, T=U
        ↓  (MDMediationResult identical shape to MI path)
   infer(type = "mc")  ← existing code, ci_mediation_data() on pooled MediationData
   infer(type = "mbco") ← see § 6 open questions
```

The shape of every object after `run()` is **identical** to the MI path, so
`pool()`, `infer()`, `print()`, `summary()`, and `tidy()` need **zero changes**.

---

## 4. `MDMediationData` changes

### 4.1 New properties

Three new optional properties handle the IPW-specific inputs.  All have sensible
defaults so `method = "mi"` objects are unaffected.

| Property | Type | Default | Purpose |
|---|---|---|---|
| `weight_formula` | `S7::class_any` | `NULL` | Formula(s) for the missingness model(s). `NULL` = use all observed predictors (`.~.`). Can be a single `formula` (joint complete-case model) or a named `list` of formulas (one per incomplete variable). |
| `weight_stabilize` | `S7::class_logical` | `TRUE` | If `TRUE`, compute stabilized weights: `w_i = P̂(R=1|X_i) / P̂(R=1|Z_i)` (numerator marginalises over covariates). Stabilized weights have lower variance and are preferred for mediation. |
| `weight_trim` | `S7::class_numeric` | `1` (= no trim) | Upper quantile at which to trim weights (e.g. `0.99`). Values outside `(0, 1]` are rejected by the validator. |

### 4.2 Validator update

The `@data` validator currently hard-requires a `mids` object.  IPW takes a raw
`data.frame` instead.  The updated rule:

```
if method == "mi"  → @data must inherit "mids"
if method == "ipw" → @data must be a data.frame (or tbl_df)
```

This is the **only validator change** needed in `MDMediationData`.

---

## 5. Weight estimation model

### 5.1 Missingness indicator

For each incomplete variable `V` (outcome `Y`, mediator `M`, or covariate),
define `R_V ∈ {0,1}` where `R_V = 1` iff `V` is observed.  The **joint
complete-case indicator** `R = ∏_V R_V` (1 iff the entire row is complete) is the
default target; per-variable models are used when `weight_formula` is a named list.

### 5.2 Propensity model

Default: logistic regression of `R` (or `R_V`) on all observed predictors in the
data, i.e. `glm(R ~ ., data = obs_cols, family = binomial)`.  The user overrides
this via `weight_formula`.  The predicted probability `p̂_i = P̂(R=1|Z_i)` is
extracted from the fitted model.

### 5.3 Unstabilized weights

```
w_i = 1 / p̂_i   (for complete cases only; dropped cases get w = 0)
```

### 5.4 Stabilized weights (default, `weight_stabilize = TRUE`)

A marginal model `glm(R ~ X, family = binomial)` (treatment only) provides the
numerator probability `p̂_i^{num}`:

```
w_i = p̂_i^{num} / p̂_i
```

The numerator formula is automatically derived from `weight_formula` by dropping
all terms except `@treatment`.  If the user supplies a named-list
`weight_formula`, the numerator for each component is its treatment-only subset.

### 5.5 Trimming

After computing raw weights, values above the `weight_trim` quantile (computed on
complete cases) are capped at that quantile value.  Trimming reduces variance at
the cost of slight bias; the default `1.0` disables trimming.

### 5.6 Weight output (stored for diagnostics)

The raw and trimmed weights are stored in a new `MDMediationFit@weights` slot
(`numeric` vector, `NA` for dropped cases) so users can inspect overlap and
trimming impact.  This is the only structural addition to `MDMediationFit`.

---

## 6. Weighted mediation fit → named `MediationData`

After computing `w_i`, the IPW fit path calls:

```r
medfit::fit_mediation(
  formula_y  = object@formula_y,
  formula_m  = object@formula_m,
  data       = complete_cases,   # rows where R == 1
  treatment  = object@treatment,
  mediator   = object@mediator,
  engine     = object@engine,
  family_y   = object@family_y,
  family_m   = object@family_m,
  weights    = w_complete         # new argument
)
```

This returns a **named `medfit::MediationData`** with `@estimates` and `@vcov`
carrying the path names (`a`, `b`, `c_prime`, …) — exactly the shape that
`pool()` and `infer()` already consume.

The result is wrapped into:

```r
MDMediationFit(
  per_imputation = list(weighted_meddata),  # list of length 1
  fits           = list(),
  weights        = w_full,                  # length = nrow(original data)
  m              = 1L,
  engine         = object@engine,
  conf_int       = object@conf_int,
  conf_level     = object@conf_level,
  source         = object
)
```

`pool()` applied to `m = 1` reduces to `Qbar = Q_1`, `B = 0`, `T = U` — the
total variance equals the within-imputation (weighted-GLM) variance.

---

## 7. Pooling and inference reuse

### 7.1 `pool()` — unchanged

No dispatch change needed.  Rubin's rules with `m = 1` are mathematically
correct (between-variance `B = 0`, total variance `T = Ubar`).  The returned
`MDMediationResult` is structurally identical to the MI result, including the
pooled named `MediationData` that `infer()` consumes.

The `tidy_table` will show `var_b = 0` for all terms, which correctly signals
no between-replicate variance for an IPW result.

### 7.2 `infer(type = "mc")` — unchanged

`RMediation::ci_mediation_data()` / `medci()` operate on the pooled `MediationData`
`@estimates`/`@vcov`.  Since those carry the correct IPW-weighted path estimates
and (weighted) variance, the Monte-Carlo CI is valid with no code change.

### 7.3 `infer(type = "mbco")` — deferred (see Open Question 5)

MBCO for IPW requires a weighted likelihood-ratio statistic.  The current
`mbco_mi.R` D4-stacking logic is MI-specific (loops over imputed datasets).
A weighted MBCO path is possible but non-trivial and is **out of scope for
Phase 1**.  Calling `infer(type = "mbco")` on an IPW object should throw an
informative `stop()`:

```
MBCO inference for IPW is not yet implemented. Use type = "mc" for IPW objects.
```

---

## 8. `run()` dispatch

The simplest implementation adds an internal branch inside the existing
`S7::method(run, MDMediationData)`:

```r
S7::method(run, MDMediationData) <- function(object, ...) {
  if (object@method == "ipw") return(.ipw_run(object, ...))
  # existing MI path ...
}
```

`.ipw_run()` is a package-internal function (not exported).  This avoids a
second S7 method dispatch and keeps the branching explicit.

Alternative: a dedicated S7 class `MDMediationIPWData` that subclasses
`MDMediationData` and gets its own `run()` method.  Simpler for now to branch
inline; upgrade to a subclass later if the IPW path grows substantially.

---

## 9. `MDMediationFit` changes

A single new property:

| Property | Type | Default | Purpose |
|---|---|---|---|
| `weights` | `S7::class_any` | `NULL` | Full-length numeric weight vector (length = `nrow(original data)`); `NA` for dropped rows. `NULL` for MI objects. |

The validator adds: if `weights` is non-`NULL`, it must be numeric and
non-negative.  No other changes to `MDMediationFit`.

---

## 10. Variance estimation

IPW introduces a known methodological tension: the weighted GLM `vcov` (from
`medfit::fit_mediation(..., weights = w)`) is model-based and does **not** account
for the fact that weights were estimated.  Three options, in ascending
correctness:

| Option | Correctness | Complexity |
|---|---|---|
| A. Model-based (weighted GLM) | Valid under correct weight model; slightly optimistic | Zero new code |
| B. HC/sandwich SE | Accounts for weight estimation; standard for IPW | Needs `sandwich::vcovHC()` post-fit |
| C. Bootstrap | Fully accounts for both steps | Heavy; better in `medsim` |

**Recommendation for Phase 1:** Option A (model-based), with a `NEWS` note that
sandwich SE is a planned enhancement.  This keeps Phase 1 as a thin wrapper.
Option B can be introduced as a `se_type = c("model", "sandwich")` argument in a
follow-on PR.

---

## 11. Acceptance criteria

- [ ] `set_md_mediation(data = df, ..., method = "ipw")` accepts a `data.frame`
      and does not error in the validator.
- [ ] `run()` on an IPW `MDMediationData` returns an `MDMediationFit` with
      `@m = 1` and one **named** `medfit::MediationData` in `@per_imputation`.
- [ ] `run()` stores non-negative IPW weights in `@weights`.
- [ ] `pool()` on the resulting `MDMediationFit` returns an `MDMediationResult`
      with `var_b = 0` for all terms.
- [ ] `infer(type = "mc")` on the pooled result returns a valid
      `RMediation::ci_mediation_data()` output.
- [ ] `infer(type = "mbco")` on an IPW object throws a clear, informative error.
- [ ] Existing MI tests (47) pass unchanged.
- [ ] A synthetic-data test verifies the IPW path end-to-end (at minimum:
      `set_md_mediation → run → pool → infer(type="mc")` on a small complete/MAR
      dataset with known true weights).
- [ ] `R CMD check` clean (E0/W0/N0).

---

## 12. Open questions

**OQ-1 (blocking): Does `medfit::fit_mediation()` accept a `weights` argument?**
The MI path never passes weights.  Phase 1 requires `medfit` to pass `weights`
through to the underlying `glm()` / `lavaan` calls.  If `medfit` lacks this, a
minor `medfit` PR (adding `weights` to `fit_mediation()` and through to
`extract_mediation()`) is needed before any IPW code can be tested.

> **RESOLVED 2026-06-11 — CONFIRMED BLOCKING.** Tested against `medfit` v0.3.0:
> `fit_mediation(..., weights = w)` **errors** (`..1 used in an incorrect
> context, no ... to look in`). `fit_mediation` forwards `...` to `stats::glm()`
> (`R/fit-glm.R` `.fit_mediation_glm`), but `glm`'s `weights` is evaluated by
> NSE in the wrong frame, so passing it via `...` fails. **Required `medfit` PR
> (prereq for Phase 1 IPW):**
> 1. Add an explicit `weights` parameter to `fit_mediation()` and
>    `.fit_mediation_glm()` and pass it to both `glm()` calls robustly (e.g. via
>    `do.call()` with the weight vector, or attach to `data` — avoid `...` NSE).
> 2. No change needed in `extract_mediation()`: it already reads
>    `stats::vcov(model_m/model_y)` (`R/extract-lm.R:322`), which returns the
>    **weighted** model-based vcov once the fit is weighted — this is exactly
>    Option A (§10).
> Track as a `data-wise/medfit` issue; `missingmed` Phase 1 IPW depends on it
> (mirrors the Phase 0 pattern where `RMediation::mbco()` needed an MI entry point).

**OQ-2 (design): Single joint-missingness formula or per-variable formulas?**
The spec supports both (a single formula → joint complete-case model; a named
list → per-variable models).  For MAR with a simple structure, the joint model is
sufficient.  For mediation, a sequential factorisation
`P(R_Y=1|X,M) × P(R_M=1|X)` is more principled (aligns with the causal ordering
X → M → Y).  Recommendation: default to the joint model; document the sequential
factorisation as the advanced option.

**OQ-3 (methodological): SE inflation from estimated weights.**
Model-based SE (Option A above) ignores the sampling variability introduced by
weight estimation.  For small samples or highly variable weights, this can lead to
undercoverage.  Phase 1 defers this via a `NEWS` note; Phase 2 or Phase 3 should
add `se_type = "sandwich"` using `sandwich::vcovHC()` (add `sandwich` to
`Imports`).  Confirm with manuscript co-author whether model-based SE is
acceptable for the paper's comparison study.

**OQ-4 (data input): `@data` type flexibility.**
The current `MDMediationData` validator (`@data` must be `mids`) must be relaxed
for IPW.  The proposed rule (§ 4.2) is the minimal change.  A cleaner long-term
design might accept `mids | data.frame` as a union type and let `method` determine
how it is used.  Phase 1 should at minimum update the validator; the union-type
redesign is optional and can wait for Phase 3 when MNAR may require other input
forms.

**OQ-5 (scope): MBCO for IPW.**
The D4-stacked MBCO in `mbco_mi.R` loops over imputed datasets; the corresponding
IPW version would compute a weighted likelihood-ratio statistic
`T_w = 2(ℓ_F^w - ℓ_C^w)` and pool it across bootstrap replicates or treat it
directly (no pooling needed for a single weighted fit).  This is methodologically
novel and out of scope for Phase 1.  Defer to Phase 3 or a dedicated manuscript
section.

**OQ-6 (dependency): Add `sandwich` to `Imports`?**
Only relevant if OQ-3 resolves to Option B in Phase 1.  If deferred to Phase 2/3,
no dependency change needed now.

---

## 13. Files affected

| File | Change |
|---|---|
| `R/MDMediationData.R` | Add `weight_formula`, `weight_stabilize`, `weight_trim` properties; update validator for `@data` type |
| `R/MDMediationFit.R` | Add `weights` property |
| `R/run.R` | Branch on `@method == "ipw"` → call `.ipw_run()` |
| `R/ipw_run.R` *(new)* | `.ipw_run()`: weight estimation + `fit_mediation(weights=)` + return `MDMediationFit(m=1)` |
| `R/infer.R` | Add IPW guard in `infer(type="mbco")` dispatch |
| `DESCRIPTION` | Possibly add `sandwich` to `Imports` (OQ-6 dependent) |
| `tests/testthat/test-ipw.R` *(new)* | Synthetic-data end-to-end test |
| `man/` | Auto-generated by roxygen2 |

---

## 14. History

- **2026-06-11** — Spec drafted (cloud agent); Phase 0 S7 migration confirmed
  complete as prereq; IPW design scoped as a thin `run()` branch + passthrough
  `pool()`; six open questions identified.
- **2026-06-11** — OQ-1 resolved empirically (CONFIRMED BLOCKING): `medfit` v0.3.0
  `fit_mediation()` does not accept `weights`; precise `medfit` PR characterized.
  Phase 1 IPW implementation is gated on that `medfit` change.
