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
| regmedint’s estimators | `"regmedint"` (requires the regmedint package; MI only) |

See [*Supported
models*](https://data-wise.github.io/missingmed/articles/supported-models.md)
and [*Structural equation
models*](https://data-wise.github.io/missingmed/articles/lavaan-sem.md).

### 3. How is the indirect effect judged? (`infer(type = )`)

|  | `"mc"` | `"mbco"` |
|----|----|----|
| Answer | an interval and point estimate for the indirect effect | a likelihood-ratio test of no indirect effect |
| Works with | `glm` and `lavaan` with MI or IPW, and `regmedint` with MI | MI with `glm`, supported `regmedint` models, or [`lavaan` with ML](https://data-wise.github.io/missingmed/articles/lavaan-sem.html#the-mbco-test-with-a-lavaan-fit) |
| Use when | you want an effect size with uncertainty | you want to test the composite null of no indirect effect |

With a treatment-by-mediator interaction, choose `treatment_level` for
the Monte Carlo interval. The MBCO test evaluates the model’s composite
no-mediation null. Its calibration depends on the model and can be
conservative when both paths are near zero. See [*Testing an indirect
effect with incomplete
data*](https://data-wise.github.io/missingmed/articles/mbco-mi.md).

## A quick path

    Missing values in the mediator, outcome or covariates?
     ├─ I can defend an imputation model  -> method = "mi"
     └─ I can model who is missing        -> method = "ipw"

    One observed mediator, regression outcome?
     ├─ yes -> engine = "glm"
     └─ latent mediator / lavaan options -> engine = "lavaan"

    Then: fit <- run(md); infer(pool(fit), type = "mc").
    Both paths weak? For supported MI models, add infer(fit, type = "mbco").
    Worried about MAR? sensitivity_mnar() (MI only).

## What no choice here fixes

- With MI, use
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/articles/sensitivity-mnar.md)
  to check how departures from MAR would affect the conclusion.
- The mediation estimates are causal only under the usual
  no-unmeasured-confounding assumptions, which missingmed does not
  address.
