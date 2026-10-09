# Testing an indirect effect with incomplete data

## What you get

One fitted object from
[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md)
gives two complementary results for the indirect effect $`a b`$:

- `infer(fit, type = "mc")`: a pooled **Monte Carlo confidence
  interval** for $`a b`$ (`"mc"` is the default `type`).
- `infer(fit, type = "mbco", ariv = "fixed")`: the **D4-MBCO
  likelihood-ratio test** of $`H_0: a b = 0`$ under multiple imputation.

Report the interval when the question is how large the indirect effect
is. Report the test when the claim is that there is an indirect effect
at all. Every MBCO call in this vignette names `ariv` explicitly;
section [Options and edge cases](#options-and-edge-cases) says what it
does.

## Before you impute: the imputation model

missingmed does not impute. It takes a
[`mice::mids`](https://amices.org/mice/reference/mids.html) object, and
the test and the interval are only as good as the imputation model
behind it. Five points matter most for mediation:

- **Congeniality.** The imputation model must include every variable in
  the analysis: the treatment, the mediator, the **outcome** and every
  covariate. An imputation model that leaves $`Y`$ out imputes $`M`$ as
  if it were unrelated to $`Y`$, which biases $`b`$ toward 0.
- **Interactions.** If the outcome model has an `X:M` term, the
  imputation model must carry that product too. There are two ways to do
  it in `mice`:
  - *Passive imputation*: add a column `XM` and give it the method
    `"~I(X * M)"`, so it is recomputed from the imputed `X` and `M` at
    every iteration and always equals their product. The mediator’s own
    imputation model should then not use `XM` as a predictor (it is a
    function of $`M`$).
  - *Impute the product as its own variable*: give `XM` an ordinary
    method. The imputed product is then free to differ from `X * M`.
    Note that missingmed’s formula `Y ~ X * M + C` recomputes the
    product from the imputed `X` and `M`.

  See the *Passive imputation* section of
  [`?mice::mice`](https://amices.org/mice/reference/mice.html) and van
  Buuren (2018) for both. The [interaction
  example](#models-with-an-xm-interaction) below uses passive
  imputation.
- **Auxiliary variables.** Include variables that predict missingness,
  or that predict the incomplete variables, even when they are not in
  the analysis model.
- **Number of imputations.** Use $`K \ge 20`$, and more when the
  fraction of missing information is high. D4 needs at least two
  imputations; `infer(type = "mbco")` refuses $`K = 1`$.
- **Reproducibility.** Pass `seed =` to
  [`mice::mice()`](https://amices.org/mice/reference/mice.html).

## Worked example

The data are synthetic: a binary treatment `X`, a mediator `M`, an
outcome `Y` and a fully observed covariate `C`, with $`a = 0.5`$,
$`b = 0.3`$ and $`n = 400`$. `M` and `Y` go missing at random, with
probabilities that depend on `C`. Because the missingness depends on an
observed variable, the complete cases are not a random subsample, and
imputation using `C` is needed.

``` r

library(missingmed)

set.seed(8644)
n <- 400
C <- rnorm(n)
X <- rbinom(n, 1, 0.5)
M <- 0.5 * X + 0.3 * C + rnorm(n)
Y <- 0.2 * X + 0.3 * M + 0.3 * C + rnorm(n)
d <- data.frame(X = X, M = M, Y = Y, C = C)

# MAR: higher C makes M more likely to be missing, lower C makes Y more likely
d$M[runif(n) < plogis(-1.8 + C)] <- NA
d$Y[runif(n) < plogis(-1.8 - C)] <- NA
round(colMeans(is.na(d)), 2)
#>    X    M    Y    C 
#> 0.00 0.17 0.18 0.00
```

Impute with all four variables in the model, then fit the mediation
model in every imputation:

``` r

imp <- mice::mice(d, m = 20, method = "norm", seed = 3051, printFlag = FALSE)

md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)
fit <- run(md)
```

## The interval

`infer(type = "mc")` pools the per-imputation estimates with Rubin’s
rules and draws a Monte Carlo interval for $`a b`$ from the pooled
estimates. Called on the fit, it pools first;
`infer(pool(fit), type = "mc")` gives the same interval up to Monte
Carlo error.

``` r

infer(fit, type = "mc", level = 0.95, n.mc = 1e5)
#> $CI
#> [1] 0.07763686 0.27354601
#> 
#> $Estimate
#> [1] 0.1660082
#> 
#> $SE
#> [1] 0.05013264
#> 
#> $MC.Error
#> [1] 0.0001585333
```

`Estimate` is the mean of the Monte Carlo draws of $`a b`$ (it differs
from $`\hat a \hat b`$ by the pooled covariance of $`\hat a`$ and
$`\hat b`$), and `CI` is the 95% interval. `MC.Error` is the Monte Carlo
error of the estimate; raise `n.mc` if it matters at the precision you
report.

## The test

``` r

res <- infer(fit, type = "mbco", ariv = "fixed")
res
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 20 imputations)
#>   D4 = 17.13 on F(1, 91.55), p = 7.734e-05
#>   r4 = 0.6319 (ariv = "fixed") | d_S = 27.96 
#>   stacked constrained fit: b = 0 branch
#>   imputations on the a = 0 branch: 20% (mixed)
```

How to read it:

- `D4` is the pooled test statistic, referred to an $`F(k, \nu)`$
  distribution. $`k`$ is the number of parameters the null constraint
  removes: 1 in this model, for either branch.
- `p` is the p-value of $`H_0: a b = 0`$.
- `r4` is the relative increase in variance due to the missing data, the
  between-imputation inflation that deflates `D4`. It is floored at 0.
- `nu` is the denominator degrees of freedom. It is `Inf` when `r4` is
  0.
- `d_S` is the likelihood-ratio statistic of the stacked data, divided
  by $`K`$.

### The result object

The result is an S7 `MbcoMIResult`. It is still a named numeric vector
`c(D4, p, r4, nu, d_S)`, so the usual indexing works, and the
diagnostics are properties:

``` r

res["p"]
#>            p 
#> 7.733747e-05
res[["p"]]
#> [1] 7.733747e-05
res@stacked_branch # the null the stacked constrained fit chose
#> [1] "b"
res@branch_mix # do the imputations' own winning branches differ?
#> [1] TRUE
res@p_branch_a # share of imputations whose own winning branch is a = 0
#> [1] 0.2
tidy(res)
#> # A tibble: 1 × 12
#>   term     statistic   df1   df2   p_value    r4   d_S ariv  stacked_branch
#>   <chr>        <dbl> <dbl> <dbl>     <dbl> <dbl> <dbl> <chr> <chr>         
#> 1 indirect      17.1     1  91.6 0.0000773 0.632  28.0 fixed b             
#> # ℹ 3 more variables: branch_mix <lgl>, p_branch_a <dbl>, m <int>
```

`res$p` is not valid: use `res["p"]` or `res[["p"]]`.

The null $`a b = 0`$ holds when $`a = 0`$**or** $`b = 0`$, so the
constrained fit is the better of two single-path fits, one per branch.
`stacked_branch` says which branch won on the stacked data. Each
imputation also has its own winning branch; `p_branch_a` is the share of
imputations whose own winner is $`a = 0`$, and `branch_mix` is `TRUE`
when the imputations do not all agree.

## Options and edge cases

### `ariv = "fixed"` or `"own"`

`ariv` sets which per-imputation statistics enter $`r_4`$:

- `ariv = "fixed"`, the default since missingmed 0.5.0, recomputes every
  imputation’s statistic on the branch the **stacked** constrained fit
  chose. All imputations then test the same constraint, with the same
  $`k`$.
- `ariv = "own"` lets each imputation use its own winning branch. It
  reproduces results from missingmed 0.4.0 and earlier on full-rank
  designs.

The two give the same result when every imputation’s own branch matches
the stacked fit’s. Reporting `branch_mix` and `p_branch_a` needs both
single-path null fits in every imputation, so each imputation is fit
three times under either option.

### Without the pipeline: `mbco_d4()`

The same test runs on any list of completed data frames:

``` r

implist <- mice::complete(imp, "all")
mbco_d4(implist, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", ariv = "fixed"
)
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 20 imputations)
#>   D4 = 17.13 on F(1, 91.55), p = 7.734e-05
#>   r4 = 0.6319 (ariv = "fixed") | d_S = 27.96 
#>   stacked constrained fit: b = 0 branch
#>   imputations on the a = 0 branch: 20% (mixed)
```

### A single imputation

D4 needs at least two imputations, so $`K = 1`$ is an informative error.
For a single complete dataset, use complete-data MBCO in RMediation
(Tofighi & Kelley, 2020).

``` r

mbco_d4(implist[1], Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", ariv = "fixed"
)
#> Error:
#> ! D4 pooling of the MBCO statistic needs at least 2 imputations; the supplied object has 1. Re-impute with m >= 2, or, for a single complete dataset, use complete-data MBCO (e.g. RMediation::mbco()).
```

### When $`k`$ differs across imputations

Under `ariv = "fixed"` every imputation is tested with the stacked fit’s
$`k`$, the number of parameters the chosen branch’s constraint removes.
When the constraint removes a different number in some imputation than
in the stacked data, for example when a level of a factor that interacts
with the treatment or mediator is absent from that imputation,
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md)
stops and names the imputation. The remedy is to drop or merge the
sparse level.

### MBCO on a pooled object

MBCO needs the per-imputation fits, so asking for it on the *pooled*
result is an error by design (see
[below](#why-mbco-does-not-commute-with-rubins-rules)):

``` r

infer(pool(fit), type = "mbco", ariv = "fixed")
#> Error:
#> ! MBCO does not commute with Rubin's rules; it needs the per-imputation fits. Call infer(type = "mbco") on the MDMediationFit from run(), not on the pooled MDMediationResult.
```

## Models with an X:M interaction

The outcome model may include a treatment-by-mediator interaction,
`Y ~ X * M + C`. The imputation model must then carry the product; here
it is imputed passively, and `XM` is removed as a predictor of `M`:

``` r

d2 <- d
d2$XM <- d2$X * d2$M
meth <- mice::make.method(d2)
meth[c("M", "Y")] <- "norm"
meth["XM"] <- "~I(X * M)"
pred <- mice::make.predictorMatrix(d2)
pred["M", "XM"] <- 0
imp2 <- mice::mice(d2,
  m = 20, method = meth, predictorMatrix = pred,
  seed = 3053, printFlag = FALSE
)

fit2 <- run(set_md_mediation(imp2, Y ~ X * M + C, M ~ X + C,
  treatment = "X", mediator = "M"
))
res2 <- infer(fit2, type = "mbco", ariv = "fixed")
res2
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 20 imputations)
#>   D4 = 10.46 on F(2, 284.2), p = 4.15e-05
#>   r4 = 0.5064 (ariv = "fixed") | d_S = 31.5 
#>   stacked constrained fit: b = 0 branch
#>   imputations on the a = 0 branch: 70% (mixed)
res2@k
#> [1] 2
```

For the $`b = 0`$ branch, the null drops **every** term that contains
`M`: here `M` and `X:M`, so that branch removes $`k = 2`$ parameters,
while the $`a = 0`$ branch removes 1. Under `ariv = "fixed"` all
imputations use the stacked fit’s branch, so there is a single $`k`$ and
the test is well defined; `res2@k` reports it. Under `ariv = "own"`,
imputations whose own winning branches differ remove different numbers
of parameters, and the test refuses to pool.

With an X:M term the indirect effect is $`a (b + \theta_3 x)`$, where
$`\theta_3`$ is the X:M coefficient: the effect of a one-unit increase
in `X` through `M`, with `X` held at $`x`$ in the outcome model. It
depends on $`x`$, so the Monte Carlo interval needs `treatment_level`.
For a 0/1 treatment, `treatment_level = 1` gives the total natural
indirect effect and `treatment_level = 0` the pure natural indirect
effect:

``` r

infer(fit2, type = "mc", treatment_level = 1)
#> $CI
#>     2.5 %    97.5 % 
#> 0.0342172 0.2572664 
#> 
#> $Estimate
#> [1] 0.1365794
#> 
#> $SE
#> [1] 0.05684491
#> 
#> $MC.Error
#> [1] 5.684491e-07
#> 
#> $Estimand
#> [1] "a * (b + theta3 * 1)"
infer(fit2, type = "mc", treatment_level = 0)
#> $CI
#>     2.5 %    97.5 % 
#> 0.0873093 0.3175738 
#> 
#> $Estimate
#> [1] 0.1905933
#> 
#> $SE
#> [1] 0.0590961
#> 
#> $MC.Error
#> [1] 5.90961e-07
#> 
#> $Estimand
#> [1] "a * (b + theta3 * 0)"
```

Without `treatment_level`, `infer(type = "mc")` stops and asks for it.
MBCO needs no such choice: its null, $`a = 0`$ or $`b = \theta_3 = 0`$,
removes the indirect effect at every $`x`$.

## Why MBCO does not commute with Rubin’s rules

The **model-based constrained optimization** (MBCO) test of mediation
tests $`H_0: a b = 0`$. Because $`a b = 0`$ iff $`a = 0`$**or**
$`b = 0`$, the constrained log-likelihood is a **branch union**: the
better of the “drop the a-path” and “drop the b-path” fits,

``` math
T = 2\left[\ell_{\text{full}} - \max(\ell_{a=0},\, \ell_{b=0})\right].
```

That [`max()`](https://rdrr.io/r/base/Extremes.html) is non-linear, so
the MBCO statistic of the *pooled* estimate is **not** the pool of the
per-imputation MBCO statistics. You cannot pool first and test second.
Instead, missingmed keeps every per-imputation fit and combines the
**likelihood-ratio statistics** with the **D4** rule (Chan & Meng, 2022;
Grund, Lüdtke & Robitzsch, 2023):

``` math
d_S = \frac{\text{LRT(stacked data)}}{K}, \quad
r_4 = \max\!\left(0, \tfrac{K+1}{k(K-1)}(\bar d - d_S)\right), \quad
D_4 = \frac{d_S}{k(1 + r_4)} \sim F_{k,\nu},
```

where $`\bar d = K^{-1} \sum_{i} d_{i}`$ averages the per-imputation
statistics. The two `ariv` options differ only in $`d_{i}`$. Let $`B`$
be the branch the stacked constrained fit chose, $`a = 0`$ or $`b = 0`$.
Then

``` math
d_{i}^{\text{fixed}} = 2\left[\ell_{\text{full}, i} - \ell_{B, i}\right],
\qquad
d_{i}^{\text{own}} = 2\left[\ell_{\text{full}, i}
  - \max(\ell_{a=0, i},\, \ell_{b=0, i})\right],
```

with $`\ell_{\cdot, i}`$ the log-likelihood in imputation $`i`$.
`"fixed"` evaluates every imputation at the same constraint $`B`$;
`"own"` takes each imputation’s maximum.

The per-imputation fits are available directly:

``` r

acc <- per_imputation_list(fit)
acc$m
#> [1] 20
length(acc$per_imputation)
#> [1] 20
```

## Not covered here

- SEM (lavaan) models and latent variables (planned).
- FIML-based MBCO.
- IPW: `method = "ipw"` has no MBCO test.

## References

- Chan, K. W., & Meng, X.-L. (2022). Multiple improvements of multiple
  imputation likelihood ratio tests. *Statistica Sinica*.
  <https://doi.org/10.5705/ss.202019.0314>
- Grund, S., Lüdtke, O., & Robitzsch, A. (2023). Pooling methods for
  likelihood ratio tests in multiply imputed data sets. *Psychological
  Methods*, *28*(5), 1207–1221. <https://doi.org/10.1037/met0000556>
- Tofighi, D., & Kelley, K. (2020). Improved inference in mediation
  analysis: Introducing the model-based constrained optimization
  procedure. *Psychological Methods*, *25*(4), 496–515.
  <https://doi.org/10.1037/met0000259>
- van Buuren, S. (2018). *Flexible imputation of missing data* (2nd
  ed.). Chapman and Hall/CRC. <https://doi.org/10.1201/9780429492259>
