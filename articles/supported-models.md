# Supported models

[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
checks the model before anything is fitted. This article lists what it
accepts and what it refuses, and runs every rule below: each refusal is
asserted, so the page fails to build if a rule changes.

``` r

library(missingmed)
set.seed(21)
n <- 300
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n), W = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[sample(n, 40)] <- NA
imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 21)

# TRUE when set_md_mediation() accepts the specification; otherwise prints the
# refusal and returns FALSE.
accepts <- function(...) {
  tryCatch({
    set_md_mediation(...)
    TRUE
  }, error = function(e) {
    cat("Refused:", conditionMessage(e), "\n")
    FALSE
  })
}
```

## The model

Two regressions with named roles:

- the **mediator model** `formula_m`, whose response is the mediator and
  which contains the treatment as a main effect;
- the **outcome model** `formula_y`, which contains the treatment and
  the mediator as main effects.

Covariates enter either model freely. Formulas are expanded against the
data first, so `Y ~ .` is checked as the model that
[`run()`](https://data-wise.github.io/missingmed/reference/run.md) fits.

## Accepted

``` r

stopifnot(
  # the basic model
  accepts(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M"),
  # a treatment-by-mediator interaction, in any spelling
  accepts(imp, Y ~ X * M + C, M ~ X + C, treatment = "X", mediator = "M"),
  accepts(imp, Y ~ M:X + X + M + C, M ~ X + C, treatment = "X", mediator = "M"),
  # covariate transforms and covariate products
  accepts(imp, Y ~ X + M + poly(C, 2) + C:W, M ~ X + C, treatment = "X", mediator = "M"),
  # a binary outcome or mediator (no X:M term)
  accepts(imp, I(Y > 0) ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M",
    family_y = binomial())
)
```

The treatment may be binary or continuous, as long as the column is
numeric. The outcome’s response may be a transform (`I(Y > 0)` above);
the mediator’s may not, as shown next.

## Refused

Each rule below names the term or argument at fault.

``` r

stopifnot(
  # formula_m must model the mediator itself
  !accepts(imp, Y ~ X + M + C, C ~ X, treatment = "X", mediator = "M"),
  # a transformed mediator needs its own column
  !accepts(imp, Y ~ X + M + C, log(M + 10) ~ X + C, treatment = "X", mediator = "M"),
  # the treatment must be a main effect of the outcome model
  !accepts(imp, Y ~ M + C, M ~ X + C, treatment = "X", mediator = "M"),
  # products other than X:M
  !accepts(imp, Y ~ X + M + X:C, M ~ X + C, treatment = "X", mediator = "M"),
  !accepts(imp, Y ~ X + M * W, M ~ X + C, treatment = "X", mediator = "M"),
  # transforms of the treatment or mediator
  !accepts(imp, Y ~ X + M + I(X^2), M ~ X + C, treatment = "X", mediator = "M"),
  # X:M outside a Gaussian identity-link model
  !accepts(imp, I(Y > 0) ~ X * M + C, M ~ X + C, treatment = "X", mediator = "M",
    family_y = binomial())
)
#> Refused: The response of `formula_m` is 'C', but `mediator` is 'M'. `formula_m` must model the mediator. 
#> Refused: The response of `formula_m` must be the mediator column 'M' itself, not 'log(M + 10)'. Create a transformed column in the data and use it as `mediator` in both formulas. 
#> Refused: `treatment` 'X' must enter `formula_y` as a main effect. 
#> Refused: Term `X:C` in `formula_y` is not supported: the treatment and mediator may enter only as main effects, plus one treatment-by-mediator interaction (`X:M`) in `formula_y`. For moderated or transformed paths, test the indirect effect with mbco_d4() on the completed datasets. 
#> Refused: Term `M:W` in `formula_y` is not supported: the treatment and mediator may enter only as main effects, plus one treatment-by-mediator interaction (`X:M`) in `formula_y`. For moderated or transformed paths, test the indirect effect with mbco_d4() on the completed datasets. 
#> Refused: Term `I(X^2)` in `formula_y` is not supported: the treatment and mediator may enter only as main effects, plus one treatment-by-mediator interaction (`X:M`) in `formula_y`. For moderated or transformed paths, test the indirect effect with mbco_d4() on the completed datasets. 
#> Refused: A treatment-by-mediator interaction (`X:M`) in `formula_y` needs Gaussian models with an identity link; `family_y` is not. Drop the interaction or use Gaussian `family_y` and `family_m`.
```

A treatment stored as a factor, character or logical column is refused
too; recode it to numeric (0/1 for a binary treatment):

``` r

d_f <- d
d_f$X <- factor(d_f$X, labels = c("control", "treated"))
meth <- mice::make.method(d_f)
meth["M"] <- "norm"
imp_f <- mice::mice(d_f, m = 2, method = meth, printFlag = FALSE, seed = 1)
stopifnot(!accepts(imp_f, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M"))
#> Refused: `treatment` 'X' must be a numeric column (0/1 for a binary treatment, or continuous), not factor. Recode it to numeric before calling set_md_mediation().
```

## Summary of the rules

| Rule | Example refused |
|----|----|
| `formula_m`’s response is the bare mediator column | `C ~ X`, `log(M) ~ X` |
| `formula_y`’s response does not involve the mediator | `M ~ X + C` as the outcome model |
| the treatment is a main effect of both models | `Y ~ M + C` |
| the mediator is a main effect of the outcome model | `Y ~ X + C` |
| treatment and mediator appear only as main effects, plus one `X:M` in the outcome model | `X:C`, `M:W`, `X:M:W`, `I(X^2)`, `poly(X, 2)` |
| `X:M` only with Gaussian identity-link models | `X:M` with `family_y = binomial()` |
| the treatment column is numeric | factor, character, logical |
| `treatment` and `mediator` are syntactic R names | `"my M"` |
| `engine` is `"glm"`, or `"regmedint"` with medfit \>= 0.4.0 and `method = "mi"` | `engine = "lavaan"` |

[`?set_md_mediation`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
lists the same rules under *Details*, together with the checks on IPW’s
`weight_formula`.

## Moderated models

Models that
[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
refuses because of a product term can still be tested for mediation with
[`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md),
which runs D4-MBCO on a plain list of completed datasets and accepts
moderated models such as `Y ~ X + M * W`. See
[`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md).

## Latent mediators

Structural equation models, including a latent mediator, run through
`set_md_mediation(engine = "lavaan")`: give the lavaan syntax in `model`
and name the `outcome`. See the *Structural equation models* article for
the call, the MBCO test with a lavaan fit, and what is refused, and the
*Migrating from the S4 API* article for the move from the old entry
points.
