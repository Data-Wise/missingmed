# Choosing an analysis

missingmed offers several estimators, engines and inference methods.
This guide picks among them. Each choice is one argument of
[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
or
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md).

## Three decisions

### 1. How are the missing values handled? (`method`)

|  | `method = "mi"` (default) | `method = "ipw"` |
|----|----|----|
| `data` | a [`mice::mids`](https://amices.org/mice/reference/mids.html) object | a raw `data.frame` |
| Idea | fill in the missing values several times, pool | keep complete cases, weight by inverse probability of being observed |
| Needs | an imputation model | a missingness model |
| Uses | every row | complete cases only |
| Inference | Rubin’s rules; MC or MBCO | robust SEs; MC only |
| Sensitivity to MNAR | [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md) | not available |

Default to **MI**: it uses all the data, supports the D4-MBCO test, and
has the sensitivity analysis. Prefer **IPW** when an imputation model
for the mediator is hard to defend but the missingness mechanism is easy
to model. Run both when you can; a large disagreement points to a
misspecified model on one side. See *Inverse probability weighting, step
by step*.

### 2. What is the model? (`engine`)

| Situation | Engine |
|----|----|
| One observed mediator, regression outcome, binary or count variables | `"glm"` (default; families via `family_m`, `family_y`) |
| Treatment-by-mediator interaction | `"glm"` (Gaussian, identity link) |
| Latent mediator, or a model easier to state as lavaan syntax | `"lavaan"` (give `model` and `outcome`) |
| A lavaan estimator such as MLR | `"lavaan"` with `fit_args` |
| regmedint’s estimators | `"regmedint"` (needs medfit 0.4.0 or later; MI only) |

See *Supported models* and *Structural equation models*.

### 3. How is the indirect effect judged? (`infer(type = )`)

|  | `"mc"` | `"mbco"` |
|----|----|----|
| Answer | an interval and point estimate for `a * b` | a likelihood-ratio test of no indirect effect |
| Works with | glm and lavaan engines, MI and IPW | glm engine, MI only |
| Use when | you want an effect size with uncertainty | the product’s interval is unreliable (both paths weak) |

The Monte Carlo interval is the default report. The MBCO test is more
reliable when both paths are weak and the product’s distribution is far
from normal. Report the interval and, if the paths are weak, the test.
See *Testing an indirect effect with incomplete data*.

## A quick path

    Missing values in the mediator, outcome or covariates?
     ├─ I can defend an imputation model  -> method = "mi"
     └─ I can model who is missing        -> method = "ipw"

    One observed mediator, regression outcome?
     ├─ yes -> engine = "glm"
     └─ latent mediator / lavaan options -> engine = "lavaan"

    Then: pool(run(md)); infer(type = "mc"). Both paths weak? Add infer(fit, type = "mbco") (MI; glm, or lavaan with ML).
    Worried about MAR? sensitivity_mnar() (MI only).

## What no choice here fixes

- MAR is an assumption, not a result. Run
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  and report the curve.
- The mediation estimates are causal only under the usual
  no-unmeasured-confounding assumptions, which missingmed does not
  address.
