# Research note — MNAR mechanisms and sensitivity analysis for mediation

**Date:** 2026-08-22 · **Audience:** internal (design input to
`SPEC-mnar-sensitivity-2026-08-22.md`) · **Status:** background, not a plan.

Literature scan run to ground the MNAR phase's design decisions rather than
invent them. Where a finding changed a decision, the SPEC records the change.

---

## 1. The taxonomy, and why MNAR is different in kind

Rubin's three mechanisms: **MCAR** (missingness independent of all data),
**MAR** (depends only on *observed* data), **MNAR** (depends on the
*unobserved* values themselves). `mice` — and therefore missingmed's entire MI
path — imputes under MAR by construction.

The operative fact for this package: **MAR vs MNAR is not testable from the
observed data.** Both are consistent with any observed dataset. Heymans &
Twisk (2022, *J Clin Epidemiol*) put it plainly: when data are MNAR, multiple
imputation does not give valid results, and one cannot determine from the data
whether MAR or MNAR holds. That is precisely why the deliverable is a
*sensitivity curve* and not an estimator — there is nothing to estimate without
an assumption supplied from outside the data.

Three modeling frameworks factor the joint distribution of data and missingness
differently:

| Framework | Factorization | Sensitivity parameter |
|---|---|---|
| **Selection model** | P(data) × P(missing \| data) | coefficient on the unobserved value in the missingness model |
| **Pattern-mixture model** | P(data \| pattern) × P(pattern) | difference in the outcome distribution between respondents and non-respondents |
| **Shared-parameter model** | joint via a latent variable | latent-variable loading |

**Delta adjustment is a pattern-mixture device.** Delta *is* the assumed
difference between the distribution of the missing values and what a MAR
imputation would produce. This matters for how the SPEC words the estimand:
delta has a pattern-mixture interpretation ("non-respondents' values run delta
higher than MAR implies"), not a selection-model one.

---

## 2. Delta adjustment / NARFCS — the method missingmed implements

Delta-adjusted MI imputes under MAR and then shifts the imputed values by a
sensitivity parameter, repeating across a grid. Its multivariate form inside
chained equations has a name in the literature: **NARFCS** (Not-At-Random Fully
Conditional Specification). What the SPEC describes *is* NARFCS with the offset
supplied through `mice`'s `post` argument, so it should say so and inherit the
literature's cautions rather than presenting itself as bespoke.

**Direct precedent for our exact use case.** Leacy et al. (2017, *Am J
Epidemiol*, 72 citations) review delta adjustment and demonstrate it **for
parametric causal mediation analysis with a partially observed mediator** —
missingmed's central case. They run two flavors worth noting:

1. a **constant** delta for everyone with a missing value;
2. a delta that **varies by an observed covariate** (there, self-reported HIV
   status used as auxiliary information).

Flavor 2 is beyond v1's scope but confirms the design should not foreclose it:
a per-stratum delta is a natural v2 extension of the same `post` mechanism.

**Other implementations to be aware of.** `SensMice` (Resseguier et al. 2011,
*Epidemiology*) adapts `mice` for exactly this and is the closest prior art in R.
Rezvan et al. (2018) demonstrate eliciting delta from an expert panel and pooling
the elicited distributions — relevant to the "how does a user choose delta?"
question the vignette must answer.

---

## 3. Finding that changed a decision: categorical targets have a standard scale

SPEC **D4** originally deferred categorical targets on the grounds that an
additive `imp + delta` is meaningless for a 0/1 imputation. That reasoning is
correct, but the implication — that no settled parameterization exists — is
**wrong**, and the SPEC has been corrected.

Resseguier et al. (2011) state the convention directly: the sensitivity
parameter is

- for **continuous** variables, the **difference in expected values**
  (missingmed's additive delta), and
- for **binary or categorical** variables, the **odds ratio** comparing the odds
  of the modality of interest among subjects with a missing value to the odds
  among subjects without.

So the correct binary construction is a **log-odds offset on the imputation
model's linear predictor**, with delta reported on the odds-ratio scale. Two
routes exist: a custom `mice` method carrying an offset, or the Heckman-based
imputation models of Galimard et al. (2018, *BMC Med Res Methodol*), which
handle MNAR binary outcomes inside MICE.

**Effect on the SPEC:** D4 still defers categorical targets out of v1 — the
offset needs a custom imputation method, not `post` post-processing — but it is
now an explicit deferral *with the v2 design named and cited*, and the error
message points the user at the reason rather than implying the case is
ill-defined.

---

## 4. Caution the SPEC must carry: substantive-model compatibility

Zhang et al. (2024) show that a **naive NARFCS implementation produces biased
effect estimates** when the imputation model is incompatible with the
substantive model — and propose NAR-SMCFCS / NAR-SMC-stack to fix it.
Compatibility means the imputation model reflects the structure of the analysis
model, including interactions.

This is a live risk here, not a theoretical one. missingmed's substantive model
is a mediation system (`M ~ X + C`, `Y ~ X + M + C`). If a user's `mids` was
built with `mice`'s defaults, the imputation model for `M` may not be compatible
with the `Y` model that consumes it. Delta adjustment does not create this
problem, but it **inherits** it, and a sensitivity curve computed on top of an
incompatible imputation is measuring two things at once.

**Effect on the SPEC:** this belongs in the documentation and the `print()`
output as a stated limitation — missingmed accepts a `mids` the user built and
cannot verify its compatibility. Substantive-model-compatible imputation
(`smcfcs`) is the recommended upstream fix and a candidate v2 integration.

---

## 5. Where the identification literature sits (deliberately not implemented)

A parallel strand seeks *identification* of mediation effects under MNAR rather
than sensitivity to it:

- **Zuo et al. (2024, JASA 120(550):794–804)** — identifiability of direct and indirect effects
  when **both mediator and outcome** are MNAR, under interpretable mechanisms.
- **Li et al. (2017, *Stat Med*)** — identifiability with missing outcomes under
  several mechanisms, with estimating-equation estimators.
- **Shan et al. (2026, JASA)** — a **shadow-variable** framework for
  nonignorable missing confounders, with semiparametric efficiency results.
- **Jin et al. (2026)** — extension to **multiple mediators** under MNAR.

These buy point identification at the cost of assumptions that are themselves
untestable (a shadow variable, an interpretable mechanism). They are a different
product from a sensitivity curve, not a better version of one. Recording them
here so a future phase can pick one up deliberately — Zuo et al. is the closest
fit to missingmed's estimand — rather than rediscovering the strand.

---

## 6. Distinction worth stating explicitly: which assumption is being probed

missingmed's package author has prior work on mediation sensitivity analysis:
**Tofighi (2021, *Frontiers in Psychology*)**, extending **CAMSA** (correlated
augmented mediation sensitivity analysis) to nonrandomized latent growth curve
mediation models.

**That method probes a different assumption.** CAMSA addresses **no omitted
confounders**; `sensitivity_mnar()` addresses **missing at random**. Both are
untestable assumptions underlying the same estimate, and a mediation analysis
can be robust to one and fragile to the other. They are complementary, and the
docs should say so rather than leaving a reader to assume "the sensitivity
analysis" covers both.

---

## 7. What this implies for the user-facing docs

1. **Never call a rung "the MNAR estimate."** A rung is conditional on its delta.
2. **Give users a way to choose delta.** Options: expert elicitation
   (Rezvan et al.), a range benchmarked against an observed effect size, or a
   **tipping-point** presentation — report the delta at which the conclusion
   changes, which sidesteps having to justify one value.
3. **State the pattern-mixture reading of delta** so the number is interpretable.
4. **State the compatibility limitation** (§4).
5. **Distinguish it from confounder sensitivity** (§6).

---

## References

All records verified against Crossref and curated in Zotero — collection
**"MNAR sensitivity — missingmed (2026-08-22)"** (My Library), 11 items with
full text attached. Years below follow the publisher record, which corrected two
of this note's first-draft citations (Zuo 2022→2024, Shan 2024→2026).


- Galimard J-E, Chevret S, Curis E, Resche-Rigon M (2018). Heckman imputation models for binary or continuous MNAR outcomes and MAR predictors. *BMC Medical Research Methodology* 18(1). doi:10.1186/s12874-018-0547-1
- Heymans MW, Twisk JWR (2022). Handling missing data in clinical research. *Journal of Clinical Epidemiology* 151:185–188. doi:10.1016/j.jclinepi.2022.08.016
- Hsu C-H, He Y, Hu C, Zhou W (2020; 2023). Multiple imputation-based sensitivity analysis for MNAR data / an MNAR covariate. *Statistics in Medicine* 39(26):3756–3771; 42(14):2275–2292. doi:10.1002/sim.8691; doi:10.1002/sim.9723
- Jin Y, et al. (2026). Mediation analysis with multiple mediators subject to MNAR.
- Leacy FP, Floyd S, Yates TA, White IR (2017). Analyses of sensitivity to the missing-at-random assumption using multiple imputation with delta adjustment. *American Journal of Epidemiology*. doi:10.1093/aje/kww107
- Li W, Zhou X-H (2017). Identifiability and estimation of causal mediation effects with missing data. *Statistics in Medicine* 36(25):3948–3965. doi:10.1002/sim.7413
- Resseguier N, Giorgi R, Paoletti X (2011). Sensitivity analysis when data are missing not-at-random. *Epidemiology* 22(2):282–287. doi:10.1097/ede.0b013e318209dec7 (`SensMice`)
- Hayati Rezvan P, Lee KJ, Simpson JA (2018). Sensitivity analysis within the MI framework using delta-adjustment. *Longitudinal and Life Course Studies* 9(3):259–278. doi:10.14301/llcs.v9i3.503
- Shan J, Li W, Ai C (2026). Efficient nonparametric inference for mediation analysis with nonignorable missing confounders. *JASA*. doi:10.1080/01621459.2026.2654218
- Tofighi D (2021). Sensitivity analysis in nonrandomized longitudinal mediation analysis. *Frontiers in Psychology* 12. doi:10.3389/fpsyg.2021.755102
- Zhang J, et al. (2024). Sensitivity analysis methods for outcome missingness using substantive-model-compatible multiple imputation.
- Zuo S, Ghosh D, Ding P, Yang F (2024). Mediation analysis with the mediator and outcome missing not at random. *JASA* 120(550):794–804. doi:10.1080/01621459.2024.2359132
- van Buuren S. *Flexible Imputation of Missing Data*, 2nd ed., §9.2 (delta adjustment).
