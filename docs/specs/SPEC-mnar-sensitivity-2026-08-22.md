# SPEC — MNAR sensitivity analysis (`sensitivity_mnar()`)

**Status:** DRAFT — **D1 needs maintainer confirmation** (marked ⚠). D4 was
revised after a literature scan and no longer needs a judgment call; see
`docs/research/RESEARCH-mnar-mechanisms-2026-08-22.md` §3.
**Branch:** `feature/mnar-sensitivity` · **Date:** 2026-08-22
**Implements:** scope-spec criterion "MNAR sensitivity analysis available for
departures from MAR" (`SPEC-missingmed-scope-2026-06-04.md`), resolving its
Open Q1.
**Plan:** `ORCHESTRATE-mnar-sensitivity.md` (untracked, worktree-local) — F1–F4
there are verified `mice` behaviors this spec treats as settled constraints.

---

## 1. What this is, and what it is not

A **sensitivity curve**, not an estimator. `sensitivity_mnar()` answers: *how far
do the conclusions move as the MAR assumption is relaxed by a stated amount?*
It identifies nothing. A rung at delta = 1.5 is not "the MNAR estimate"; it is
the estimate one would obtain **if** the unobserved values were on average 1.5
units higher than MAR-based imputation implies.

Method: **delta-adjusted imputation** (van Buuren, *FIMD* §9.2). Each rung
re-imputes with an offset applied to the target's imputed values, then runs the
existing pipeline unchanged. In its multivariate form inside chained equations
this is **NARFCS** (Not-At-Random Fully Conditional Specification) — naming it
matters, because it means this design inherits the literature's cautions (§5)
rather than being bespoke.

**Delta is a pattern-mixture parameter**, not a selection-model one: it is the
assumed difference between the non-respondents' distribution and what a MAR
imputation produces. Read a rung as "if the unobserved values run delta higher
than MAR implies, the indirect effect is X."

**Direct precedent.** Leacy et al. (2017, *Am J Epidemiol*) apply delta-adjusted
MI to **parametric causal mediation with a partially observed mediator** — this
package's central case. Background and full citations:
`docs/research/RESEARCH-mnar-mechanisms-2026-08-22.md`.

---

## 2. Decisions

### D1 ⚠ — `mechanism` becomes derived, not user-set

**Decision.** `mechanism` stops being an argument of `set_md_mediation()` and
becomes a record of *what produced the object*. Supplying it emits a deprecation
warning for one cycle and is otherwise ignored. `sensitivity_mnar()` stamps
`mechanism = "mnar"` on the per-rung objects it creates; everything else is
`"mar"`.

**Rationale.** Today `mechanism = "mnar"` validates (`MDMediationData.R:86`),
prints (`methods-output.R:15`) and changes nothing — `run()` estimates under MAR
either way. A property that reads like it switches the estimator while silently
doing nothing is a correctness trap, not a convenience. The property should
describe what happened, not what the user hoped for.

**Alternative rejected.** Erroring on `mechanism = "mnar"` is more forceful but
breaks a documented argument outright; a deprecation warning matches how the
package already retired the S4 entry points.

> ⚠ **Confirm:** this is a (small) user-facing API change on an argument that
> currently does nothing. The alternative is to leave it purely declarative and
> document the no-op loudly.

### D2 — Delta parameterization: numeric vector, or a data.frame for joint grids

**Decision.**

```r
sensitivity_mnar(object, delta, target = NULL, type = c("mc", "mbco"), ...)
```

- `delta` **numeric vector** → one rung per value, applied to `target`.
- `delta` **data.frame** → one rung per row, one column per target variable
  (column names are the variables); `target` must then be `NULL`.
- `target` defaults to the mediator (`object@mediator`).

**Rationale.** The vector form covers the overwhelmingly common single-variable
curve; the data.frame form covers joint grids without inventing a formula DSL,
and `expand.grid()` already produces exactly that shape.

### D3 — Shiftable variables: any incomplete column, mediator by default

**Decision.** `target` must name a column of `object@data$data` with at least one
missing value (`nmis > 0`). A target with no missingness is an **error**, not a
silent no-op, because a delta on a fully observed variable does nothing and
almost certainly indicates a typo.

### D4 — Categorical targets: deferred to v2, on the odds-ratio scale

**Decision.** v1 **errors** for a target that is a factor, logical, or imputed by
a categorical method (`logreg`, `polyreg`, `polr`, `lda`), naming the target and
the reason. v2 implements it as a **log-odds offset on the imputation model's
linear predictor**, with delta reported on the **odds-ratio** scale.

**Rationale.** The additive shift on drawn values is meaningless for a binary
target: imputations are 0/1 and `imp + 1.5` yields 1.5/2.5 — not a probability,
not a category. But the construction itself is **fully defined**, and Leacy et
al. (2017) write it down: δ enters the imputation model's linear predictor as an
offset on the response indicator,

> logit{Pr[Y = 1 | X, R]} = Φ₀ + Φ'ₓX + δ(1 − R)

so that δ "represents the difference in the log-odds of Y = 1 for individuals
with missing Y values compared with individuals with observed Y values."

The v1 refusal is therefore purely an **effort** deferral: expressing that offset
needs a custom `mice` imputation method, because `post` operates on drawn values
rather than on the linear predictor. It is not a conceptual gap, and the error
message must not imply one.

**The two-mechanism split is standard, not our invention.** Hayati Rezvan et al.
(2018) **[full text]** state it directly: for continuous variables the procedure
imputes under MAR and *then* adds the constant, whereas "for categorical
incomplete variables, the missing values are drawn from an imputation model
assuming MNAR, which proceeds by **adding offsets to the linear predictors**" —
and in that case the post-hoc addition step "is omitted." So the continuous and
categorical paths are *meant* to differ in mechanism; v1 implements the first and
defers the second. Delegating to the NARFCS extension (§3.0) would supply both.

**Revised after reading the sources.** The original draft implied no settled
parameterization existed for categorical targets. That was wrong. Resseguier et
al. (2011, *Epidemiology* 22(2):282–287, verified against the full text) give
three cases:

| Target | Sensitivity parameter θ |
|---|---|
| continuous | difference in expected values (this SPEC's delta) |
| binary / categorical | **odds ratio**, comparing odds of the modality of interest among those with a missing value to the odds among those without |
| standardized | the difference expressed as a **coefficient of variation** |

For a **polytomous** target, θ is a **vector** — one entry per non-reference
modality (their trinary example runs θ = [1.2; 1.2] and [1.2; 1.5]). D2's
data.frame grid must therefore accommodate a vector-valued θ per target when v2
lands, not a scalar.

So D4 is an **effort deferral with a known target design**, not an open question
— and the error message must say "not yet implemented", never anything implying
the case is ill-defined.

Two implementation routes for v2: a custom `mice` method carrying the offset, or
the Heckman-based MICE imputation models of Galimard et al. (2018), which handle
MNAR binary outcomes directly.

### D5 — IPW: error with guidance

**Decision.** `sensitivity_mnar()` on `method = "ipw"` errors, mirroring the
existing IPW refusal in `infer(type = "mbco")` (`R/infer.R`).

**Rationale.** Delta-adjusted imputation shifts imputations; IPW has none. A
weighting analogue would perturb the missingness model or tip the weights — a
different method with a different sensitivity parameter, not a variant of this
one. Out of scope; the error says so rather than leaving the user to infer it.

### D6 — Result class: `MDSensitivityResult`

**Decision.** A fourth S7 class, mirroring the existing three:

| Property | Contents |
|---|---|
| `@rungs` | list, one entry per rung: the `infer()` output |
| `@grid` | data.frame of the delta values (one column per target) |
| `@target` | character, the shifted variable(s) |
| `@type` | `"mc"` or `"mbco"` |
| `@source` | the originating `MDMediationData` |

With `print()`, `summary()` and `tidy()` per `R/methods-output.R`. `tidy()`
returns one row per rung: the delta column(s), `estimate`, `conf_low`,
`conf_high` (or the D4 statistic and p for `type = "mbco"`).

**Rationale.** A bare tibble discards the pooled objects; a bare list has no
print method. The class carries both and matches the package's existing shape.

---

## 3. Mechanics

### 3.1 Re-imputation (settled by ORCHESTRATE F1/F2)

Rebuild from the `mids`' **stored slots**, never from `mids$call`:

```r
mice::mice(md@data$data,
           m = md@data$m, method = md@data$method,
           predictorMatrix = md@data$predictorMatrix,
           visitSequence  = md@data$visitSequence,
           where = md@data$where, blots = md@data$blots,
           post  = <composed>, seed = <pinned>, printFlag = FALSE)
```

`mids$call` references the caller's local symbols and does not resolve outside
the function that built it (F1). Rebuilding from slots reproduced **identical**
imputations (F2).

### 3.1b What delta is added to — corrected against the source

**The canonical definition applies delta to the imputation model's LINEAR
PREDICTOR, not to the drawn value.** Leacy et al. (2017), §Delta-adjustment
procedure, verbatim:

> "implementation of the delta-adjustment procedure involves adding a fixed
> quantity δ to the linear predictor before imputing missing data using the
> updated model. As such, it is a simple type of pattern-mixture model."

with the binary case written explicitly as

> logit{Pr[Y = 1 | X, R]} = Φ₀ + Φ'ₓX + δ(1 − R),  R = 1 if observed, 0 if missing

This SPEC's mechanism (`post`, §3.2) adds delta to the **drawn value** instead.
When the two coincide, and when they do not:

| Imputation method | `post` shift vs linear-predictor shift |
|---|---|
| `norm`, `norm.nob`, `norm.boot` | **Identical.** The draw is `Xβ̇ + ε`; adding δ before or after the noise is the same number. |
| `pmm` (mice's default) | **NOT identical.** Adding δ to the linear predictor shifts the *matching target*, then a donor is drawn from observed values — so the result stays inside the observed range. Adding δ afterwards shifts the donor itself, and can leave that range. |
| `logreg` / categorical | **Not comparable.** The draw is 0/1; only the linear-predictor form is defined (see D4). |

**Consequence for v1:** the `post` mechanism is exact for `norm*` targets and an
approximation for `pmm` — and `pmm` is `mice`'s default for numeric variables,
so this is the common case, not an edge case. v1 therefore either restricts to
`norm*` targets or documents the `pmm` divergence prominently. **This is an open
implementation question for M2**, raised here because it was missed when the
mechanism was chosen from an abstract rather than from the method text.

### 3.2 `post` is composed, never overwritten

The user's `mids` may already carry `post` expressions. The delta line is
**appended** to the target's existing entry, separated by `;`, so user
post-processing survives:

```r
post[target] <- paste(c(existing_post[target],
                        "imp[[j]][, i] <- imp[[j]][, i] + <delta>"),
                      collapse = "; ")
```

Overwriting would silently discard user semantics — the same class of bug as D1.

**Verified.** A `;`-composed entry runs both statements. With a user rule
`imp <- pmax(imp, -1)` composed with a delta of 3, mice evaluated
`imp[[j]][, i] <- pmax(imp[[j]][, i], -1); imp[[j]][, i] <- imp[[j]][, i] + 3`
and both took effect.

**Test-design trap this exposed.** The observed mean shift was **3.182**, not 3.
The gap is not error: the shifted `M` feeds `Y`'s imputation model, and `Y` feeds
`M`'s on the next iteration, so part of the delta circulates back through the
chained equations. **A test asserting that the imputed mean moves by exactly
`delta` will fail.** Assert direction and monotonicity instead (criterion 2).

### 3.3 Seed (settled by F3)

`mids$seed` is `NA` unless the user passed one. Therefore:

- `mids$seed` is a real value → reuse it for **every** rung.
- `mids$seed` is `NA` → use the `seed` argument (default: a fixed integer), and
  **say so in `print()`**.

Rungs must differ only by delta. Reseeding per rung would mix Monte-Carlo noise
into the curve and make it uninterpretable.

### 3.4 The `delta = 0` guarantee — stated precisely (`post` mechanism only; see §3.0)

- **`mids$seed` available:** the `delta = 0` rung reproduces the original MAR
  analysis **exactly**. This is the primary acceptance test. **Verified:** a
  `delta = 0` post entry re-run at the same seed produced imputations identical
  to the unmodified `mice()` call (`all.equal(z0$imp, base$imp)` -> `TRUE`), so
  the no-op expression does not perturb the RNG stream.
- **`mids$seed` is `NA`:** the `delta = 0` rung reproduces *a* MAR analysis under
  the pinned seed — statistically equivalent to the original, not bit-identical.
  Documented, and asserted differently in tests.

Conflating these two would produce a test that passes locally and fails for any
user who omitted a seed.

---

### 3.0 OPEN FORK — hand-roll via `post`, or delegate to the NARFCS `mice` extension?

**A reference implementation already exists.** Tompsett et al. (2018)
**[full text]**: NARFCS "can be implemented using modifications to existing
software packages for MICE... an extension to the R package `mice`... currently
available on GitHub under the URL
`https://github.com/moreno-betancur/NARFCS`." Kawabata et al. (2024)
**[full text]** used it: "Monte Carlo NARFCS was implemented in R using the
NARFCS extension to mice, and in Stata using `mi impute` with option `offset`."

This is a genuine architectural fork, and it should be settled before M2:

| | `post` composition (this SPEC) | NARFCS extension |
|---|---|---|
| Consistency with the package's stated role | poor — hand-rolls the missingness middle | **good** — missingmed is a thin orchestration layer that delegates |
| Parameter interpretability | criticised by Tompsett as not formally defined | formal MNAR imputation model |
| Categorical targets (D4) | blocked | supported natively |
| Dependency | none | **GitHub-only, not on CRAN** — hostile to a CRAN-targeted package |
| `delta = 0` identity | holds (verified) | **does NOT hold** — see below |

**The `delta = 0` guarantee does not survive delegation.** Tompsett, verbatim:

> "We note that imputing under NARFCS setting all sensitivity parameters to zero
> is **not** equivalent to imputing under standard FCS due to the presence of the
> M₋ⱼ terms in the models."

NARFCS additionally includes the missingness indicators of the *other* incomplete
variables as predictors, so its delta = 0 rung is not the MAR analysis. §3.4's
primary acceptance test is therefore **specific to the `post` mechanism** and
must be restated if this fork is taken the other way.

**Recommendation:** keep `post` for v1 (no non-CRAN dependency, and the delta = 0
identity is worth having as a correctness anchor), but state the limitation
honestly and treat NARFCS delegation as the v2 direction — at which point D4
comes free.

### 3.4b The CSP/MSP gap — the most consequential finding, and it is ours to handle

**`delta` is a CONDITIONAL sensitivity parameter (CSP). It is almost certainly
not the number a user thinks they are supplying.** Tompsett et al. (2018), the
canonical NARFCS paper **[full text]**:

> "NARFCS sensitivity parameters are the specified differences between imputed
> and observed values of a variable, **conditional on all remaining variables of
> the data and their missingness indicators**. We therefore refer to them as
> conditional sensitivity parameters, or CSPs... Most sensitivity parameters are
> marginal on at least some of the remaining variables and hence referred to as
> **marginal sensitivity parameters (MSP)**. Direct elicitation of a CSP is
> typically not feasible."

An analyst asked "how much higher are non-respondents?" answers with an **MSP**.
`sensitivity_mnar(delta = 0.5)` consumes it as a **CSP**. Tompsett's simulation
measures what that costs:

| Input | Bias, E(Y₂) | Coverage (nominal 95%) |
|---|---|---|
| true values | 0.000 | 95.0% |
| **elicited MSP inserted as the CSP** | **0.301** | **49.3%** |
| calibrated CSP | 0.002 | 95.1% |

Coverage collapses to roughly half of nominal. This is not a subtle caveat — it
is the single most likely way a user misreads this function, and the failure is
silent.

**This also explains the 3.182 observation** in §3.2. That was not incidental
"propagation": the specified CSP of 3 realized as a marginal shift of ≈3.18. The
gap between the two *is* the CSP/MSP gap, and Tompsett show the bias worsens as
it widens.

**v1 requirements arising:**

1. The `delta` argument is documented as a **CSP** wherever it appears —
   `?sensitivity_mnar`, the vignette, and `print()`.
2. **Report the realized MSP per rung.** It is cheap: the marginal mean
   difference between imputed and observed values of the target is computable
   from the imputations already in hand. `tidy()` gains an `msp` column so the
   user sees the gap rather than assuming there is none.
3. §4.5's tipping-point recommendation is **qualified**: Tompsett note the
   tipping point on the CSP scale "does not have a clear clinical
   interpretation." Report the tipping point with its realized MSP alongside.
4. **Calibration** — searching for the CSP that realizes a target MSP — is the
   principled fix and is **v2**, named here so it is not reinvented.

**Related criticism to absorb, not dismiss.** Tompsett describe the van Buuren
and Resseguier style approaches — which is what §3.2's `post` mechanism is — as
methods that "do not include formally defined imputation models," making the
sensitivity parameters hard to interpret precisely. Requirement 2 above is the
mitigation available to us without reimplementing NARFCS: if we cannot make the
specified parameter interpretable, we can at least report the realized one.

### 3.5 Stated limitation: substantive-model compatibility

*(The claim below came from an abstract for a paper — Zhang et al. 2024 — that
could not be located in Crossref, arXiv, Europe PMC or Semantic Scholar. It is
retained as a plausible concern, explicitly unverified, and no requirement rests
on it. The verified NARFCS pitfall is §3.4b.)*

Zhang et al. (2024) **[abstract only, source not located]** report that a naive
NARFCS implementation is biased when the imputation model is incompatible with
the substantive model — i.e. when the imputation model does not reflect the
analysis model's structure, interactions included.

This applies here. The substantive model is a mediation system (`M ~ X + C`,
`Y ~ X + M + C`), while the `mids` arrives **pre-built by the user** and
missingmed cannot verify how it was specified. If the imputation of `M` is
incompatible with the `Y` model consuming it, the resulting curve confounds two
effects: departure from MAR, and imputation-model misspecification.

Delta adjustment does not cause this, but it **inherits** it. Therefore:

- `print()` on `MDSensitivityResult` states that the curve assumes the supplied
  imputation model is compatible with the mediation model.
- The vignette names `smcfcs` (substantive-model-compatible FCS) as the upstream
  fix, and NAR-SMCFCS as the compatible-sensitivity method.
- Integrating either is **v2**, not v1.

Not detectable from our side, so it is documented rather than checked.

---

## 4. Acceptance criteria

1. `delta = 0` reproduces the MAR analysis, per the §3.4 distinction.
2. A monotone delta grid produces a monotone shift in the indirect effect for a
   DGP constructed to make that true.
3. A user's pre-existing `post` entry survives re-imputation (§3.2).
4. Every documented refusal — D3 no-missingness, D4 categorical target, D5 IPW —
   has a test asserting its message.
5. `tidy()` returns one row per rung with the delta column(s), the **realized
   MSP**, and the interval (§3.4b requirement 2).
6. Suite green; `R CMD check --as-cran` Status OK.

---

### 4.5 Documentation requirements (not optional)

1. **Never present a rung as "the MNAR estimate."** Every rung is conditional on
   its delta.
2. **Give the user a way to choose delta — and warn what delta is.** Routes:
   expert elicitation with pooled elicited distributions (Hayati Rezvan et al.
   2018), a range benchmarked against an observed effect size, or a
   **tipping-point** presentation. Every one of them elicits an **MSP**, while
   the argument is a **CSP** (§3.4b) — so the docs must say so plainly, and
   `summary()` must report the tipping point together with its realized MSP,
   since Tompsett et al. note a CSP-scale tipping point has no clear clinical
   interpretation on its own.
3. **State the pattern-mixture reading** (§1) so delta is interpretable.
4. **Distinguish this from confounder sensitivity.** `sensitivity_mnar()` probes
   the **MAR** assumption. CAMSA (Tofighi 2021) probes the **no-omitted-
   confounder** assumption. Both underlie the same estimate, and an analysis can
   be robust to one and fragile to the other, so the docs must not let a reader
   assume "the sensitivity analysis" covers both.

---

## 5. Out of scope

- Point identification under MNAR.
- Selection-model or pattern-mixture estimation beyond delta adjustment.
- A weighting-based MNAR sensitivity for IPW (D5).
- Link-scale offsets for categorical targets (D4) — the first candidate for v2,
  with the design already fixed (odds-ratio-scaled delta).
- **CSP calibration** — searching for the CSP that realizes a target MSP
  (Tompsett et al. 2018, §8). The principled fix for §3.4b; v2.
- Covariate-varying delta (Leacy et al.'s second flavor: delta differing by an
  observed auxiliary variable). The `post` mechanism extends to it naturally;
  v1 keeps delta constant across all missing values of a target.
- **Identification** under MNAR, as distinct from sensitivity to it — Zuo et al.
  (2024, JASA) for mediator-and-outcome MNAR, Li et al. (2017) for missing
  outcomes, Shan et al. (2026) for shadow variables. These buy point
  identification with untestable assumptions of their own; a different product,
  not a better version of this one.
- `medrobust` reuse. Scope-spec Open Q1 asked whether its bounds machinery
  transfers; it addresses misclassification, not missingness, and the sensitivity
  parameter has no shared meaning. **Open Q1 is hereby answered: no reuse.**
