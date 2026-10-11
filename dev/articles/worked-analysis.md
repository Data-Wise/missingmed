# A worked analysis with a missing mediator

This tutorial walks through a complete mediation analysis when the
mediator is partly missing. It follows the steps of a typical applied
analysis of a randomized study, on simulated data so that every number
here can be reproduced from this page:

1.  analyze the complete data, as a reference;
2.  delete part of the mediator at random, given observed variables
    (MAR);
3.  impute the mediator;
4.  pool a Monte Carlo confidence interval for the indirect effect;
5.  test the indirect effect with D4-MBCO;
6.  repeat steps 3 to 5 on a dataset where both paths are weak;
7.  ask how far the conclusion depends on MAR.

The tutorial has two parts. **Part 1** is the core analysis, which works
the same way in missingmed 0.5.0. **Part 2** shows what later versions
add: checks that catch a mis-specified model before it is fitted,
clearer errors, a treatment-by-mediator interaction, and more control
over the sensitivity analysis. Each Part 2 section says what 0.5.0 did
instead.

``` r

library(missingmed)
```

We call [`mice::mice()`](https://amices.org/mice/reference/mice.html)
with its package prefix instead of attaching mice. Both packages export
a
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md);
if you run [`library(mice)`](https://github.com/amices/mice) after
[`library(missingmed)`](https://github.com/Data-Wise/missingmed),
`pool(fit)` calls
[`mice::pool()`](https://amices.org/mice/reference/pool.html) and fails
with “Argument ‘object’ not a list”. Attach mice first, or use
[`missingmed::pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md).

## Part 1: the core analysis

### The data

A randomized two-arm program (`treat`, 0 or 1) is meant to change an
outcome `Y` through a mediator `M`. Two baseline covariates, `base` and
`hard`, are measured before randomization and predict both `M` and `Y`.
The function below simulates such a study; the true paths are `a`
(treatment to mediator), `b` (mediator to outcome) and `cp` (the direct
effect).

``` r

simulate_study <- function(n, a, b, cp, seed) {
  set.seed(seed)
  base <- rnorm(n)
  hard <- rnorm(n)
  treat <- rbinom(n, 1, 0.5)
  M <- a * treat + 0.30 * base - 0.20 * hard + rnorm(n)
  Y <- b * M + cp * treat + 0.40 * base + 0.25 * hard + rnorm(n)
  data.frame(treat, base, hard, M, Y)
}

full <- simulate_study(n = 600, a = 0.35, b = 0.30, cp = 0.10, seed = 4021)
head(full)
#>   treat        base       hard          M           Y
#> 1     1 -0.69673545 -0.1788660 -1.2775802  0.26060581
#> 2     0  0.02189903  1.0136320 -0.0433111 -0.72926874
#> 3     0  1.87833449  1.0044522  0.1195636  2.77334319
#> 4     0 -0.94634660 -0.2009755 -0.2179636  0.02458058
#> 5     0  2.04674042  1.1932109 -1.1862256  1.14839717
#> 6     0 -0.48401985  1.5490305  1.2755799  0.30367648
```

The true indirect effect is `a * b = 0.35 * 0.30 = 0.105`.

### Step 1: the complete-data reference

Before deleting anything, fit the two regressions on the full data.
missingmed fits through `medfit`, so the same call works on any data
frame; here we use
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html)
directly.

``` r

ref <- medfit::fit_mediation(
  formula_y = Y ~ treat + M + base + hard,
  formula_m = M ~ treat + base + hard,
  data = full, treatment = "treat", mediator = "M"
)
c(a = ref@a_path, b = ref@b_path, ab = ref@a_path * ref@b_path)
#>          a          b         ab 
#> 0.30234425 0.31336523 0.09474418
```

The estimates are close to the truth. This is the answer the analyses
below should recover.

### Step 2: make the mediator missing at random

The mediator is deleted with a probability that rises with baseline
`base`, with `hard`, and in the treated arm. Each of those is observed,
so the mediator is missing at random (MAR): given the observed
variables, whether `M` is missing does not depend on the value of `M`
itself.

``` r

set.seed(77)
p_miss <- plogis(-1.4 + 0.6 * full$base + 0.4 * full$treat + 0.3 * full$hard)
obs <- full
obs$M[runif(nrow(obs)) < p_miss] <- NA
mean(is.na(obs$M))
#> [1] 0.265
```

About a quarter of the mediator values are now missing. Dropping those
rows (complete-case analysis) would lose that much data and, because the
rows lost are not a random subset, can bias the estimates.

### Step 3: impute the mediator

Multiple imputation replaces each missing value with several plausible
ones. Two choices matter:

- **Include the outcome in the imputation model.** `mice` uses every
  other column as a predictor by default, so `Y` helps impute `M`.
  Leaving it out would make the imputation model assume no relation
  between `M` and `Y`, and pull the `b` path toward zero.
- **Use enough imputations.** We use `m = 10`; more imputations reduce
  the Monte Carlo noise in the pooled results.

``` r

imp <- mice::mice(obs, m = 10, method = "pmm", printFlag = FALSE, seed = 2718)
```

Now describe the mediation model once.
[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md)
stores the data, the two regressions and the roles of the variables;
nothing is fitted yet.

``` r

md <- set_md_mediation(imp,
  formula_y = Y ~ treat + M + base + hard,
  formula_m = M ~ treat + base + hard,
  treatment = "treat", mediator = "M"
)
md
#> <MDMediationData>
#>   estimator (method): mi | mechanism: mar 
#>   imputations (m)   : 10 
#>   treatment / mediator: treat / M 
#>   outcome model : Y ~ treat + M + base + hard 
#>   mediator model: M ~ treat + base + hard 
#>   engine: glm
```

[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md)
fits both regressions on each of the 10 completed datasets, and
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md)
combines them with Rubin’s rules.

``` r

fit <- run(md)
res <- pool(fit)
res
#> <MDMediationResult> (pooled, Rubin's rules; m = 10 )
#>     term   estimate  std_error
#>        a 0.28120272 0.09417501
#>        b 0.33726970 0.04263808
#>  c_prime 0.07610106 0.08133278
#>   indirect effect a*b = 0.0948 
#>   -> infer(type = "mc") for the indirect-effect CI
```

Rubin’s rules average the 10 estimates, and add the spread between
imputations to the average within-imputation variance. That extra spread
is the price of not observing the missing values.

### Step 4: a pooled Monte Carlo interval

The indirect effect is a product, `a * b`, and its sampling distribution
is not normal. `infer(type = "mc")` draws `(a, b)` from a normal
distribution with the pooled estimates and pooled covariance, and reads
the interval off the distribution of the products.

``` r

set.seed(1)
mc <- infer(fit, type = "mc")
mc$CI
#> [1] 0.03063534 0.16804564
```

The interval excludes zero and covers the true value 0.105. Note that
`mc$Estimate` is the mean of the draws, which includes the covariance of
`a` and `b`; it is not exactly the product of the pooled `a` and `b`.

### Step 5: test the indirect effect with D4-MBCO

The Monte Carlo interval answers “which values of `a * b` are
plausible”. A test answers “is `a * b` zero”. The model-based
constrained optimization (MBCO) test compares the fit of the full model
with the best fit in which the indirect effect is zero, that is, with
`a = 0` or with `b = 0`.

Under multiple imputation, MBCO cannot simply be averaged across
imputations. `infer(type = "mbco")` uses the D4 statistic instead: it
fits the full and the constrained models to all imputed datasets stacked
together, then corrects for the extra variance due to imputation.

``` r

mbco <- infer(fit, type = "mbco", ariv = "fixed")
mbco
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 10 imputations)
#>   D4 = 9.126 on F(1, 286.7), p = 0.002747
#>   r4 = 0.2153 (ariv = "fixed") | d_S = 11.09 
#>   stacked constrained fit: a = 0 branch
#>   imputations on the a = 0 branch: 100% (not mixed)
mbco[["p"]]
#> [1] 0.002746585
```

The printout reports the D4 statistic and its F reference distribution,
the relative increase in variance due to missing data (`r4`), and which
path the stacked constrained fit set to zero. Here every imputation
agrees that setting `a = 0` is the better constrained fit, so the two
`ariv` choices explained in step 6 give the same answer.

### Step 6: when both paths are weak

The same steps on a study with small `a` and `b`:

``` r

weak <- simulate_study(n = 600, a = 0.10, b = 0.09, cp = 0.05, seed = 41)
set.seed(78)
p_miss <- plogis(-1.4 + 0.6 * weak$base + 0.4 * weak$treat + 0.3 * weak$hard)
weak$M[runif(nrow(weak)) < p_miss] <- NA

imp_w <- mice::mice(weak, m = 10, method = "pmm", printFlag = FALSE, seed = 2718)
fit_w <- run(set_md_mediation(imp_w,
  formula_y = Y ~ treat + M + base + hard,
  formula_m = M ~ treat + base + hard,
  treatment = "treat", mediator = "M"
))
set.seed(2)
infer(fit_w, type = "mc")$CI
#> [1] -0.01331304  0.01124771
```

With both paths near zero, the imputations can disagree about which path
to constrain: in some completed datasets the `a = 0` model fits better,
in others the `b = 0` model does. The `ariv` argument says how D4
handles that.

``` r

fixed <- infer(fit_w, type = "mbco", ariv = "fixed")
own <- infer(fit_w, type = "mbco", ariv = "own")
fixed
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 10 imputations)
#>   D4 = 0.1104 on F(1, 47.05), p = 0.7411
#>   r4 = 0.7774 (ariv = "fixed") | d_S = 0.1963 
#>   stacked constrained fit: a = 0 branch
#>   imputations on the a = 0 branch: 30% (mixed)
rbind(fixed = S7::S7_data(fixed), own = S7::S7_data(own))
#>              D4         p        r4       nu       d_S
#> fixed 0.1104414 0.7411183 0.7773637 47.04859 0.1962945
#> own   0.1962945 0.6577286 0.0000000      Inf 0.1962945
```

- `ariv = "fixed"` (the default) takes the branch the **stacked**
  constrained fit chose and tests every imputation on that same branch.
- `ariv = "own"` lets each imputation use its own better branch when
  computing the variance correction `r4`.

When the branches are mixed, as here (`branch_mix` is `TRUE` in the
printout), the two choices give different `r4` and p-values. When they
are not mixed, as in step 5, they agree exactly. Report which one you
used;
[`mbco_d4()`](https://data-wise.github.io/missingmed/dev/reference/mbco_d4.md)
documents both.

### Step 7: how much does the conclusion depend on MAR?

MAR cannot be checked from the observed data.
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)
asks what happens if the missing mediator values are systematically
higher or lower than MAR imputation assumes. It re-imputes with the
imputed values shifted by `delta` (in the mediator’s units) and repeats
the inference at each shift.

``` r

sens <- sensitivity_mnar(md, delta = c(0, -0.5, -1, -1.5, -2),
  type = "mc", n.mc = 2e4
)
summary(sens)
#> MNAR sensitivity curve -- mc | target: M 
#> 
#> # A tibble: 5 × 7
#>       M    msp estimate conf_low conf_high mechanism scale
#>   <dbl>  <dbl>    <dbl>    <dbl>     <dbl> <chr>     <chr>
#> 1   0    0.138   0.0951  0.0313     0.168  post      raw  
#> 2  -0.5 -0.362   0.0837  0.0226     0.155  post      raw  
#> 3  -1   -0.862   0.0681  0.0121     0.134  post      raw  
#> 4  -1.5 -1.36    0.0522  0.00290    0.111  post      raw  
#> 5  -2   -1.86    0.0385 -0.00430    0.0899 post      raw  
#> 
#> Tipping point: the smallest departure at which the null is
#>   retained is delta = -2 (realized msp = -1.8615 ).
#> A CSP-scale tipping point has no direct clinical reading -- judge
#> plausibility on the realized msp, and only call the result fragile if
#> that departure from MAR is itself plausible.
```

`delta = 0` is the MAR analysis. The tipping point is the smallest shift
at which the interval includes zero. Column `msp` is the mean of the
imputed mediator values minus the mean of the observed ones. It is not
zero even at `delta = 0`: under MAR the people with a missing mediator
have higher `base`, so their imputed values are higher on average.
Compare each row’s `msp` with the `delta = 0` row to see how much the
shift moved the imputations, and judge whether a departure that large is
plausible for your study.

## Part 2: new since missingmed 0.5.0

Everything in Part 1 runs the same way in missingmed 0.5.0. The sections
below show behavior added after 0.5.0, and what 0.5.0 did instead.

### The model is checked before it is fitted

A typo in a formula used to be fitted without complaint. Here the
mediator model regresses a covariate, not the mediator, on the
treatment:

``` r

set_md_mediation(imp,
  formula_y = Y ~ treat + M + base + hard,
  formula_m = base ~ treat + hard,
  treatment = "treat", mediator = "M"
)
#> Error:
#> ! The response of `formula_m` is 'base', but `mediator` is 'M'. `formula_m` must model the mediator.
```

In 0.5.0 this call succeeded, and the pipeline reported the effect of
treatment on `base` as the `a` path, a silently wrong indirect effect.
[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md)
now also refuses, with a message naming the problem:

- a treatment or mediator missing from either formula;
- a product or transform involving the treatment or mediator other than
  one `treat:M` term
  ([`mbco_d4()`](https://data-wise.github.io/missingmed/dev/reference/mbco_d4.md)
  accepts moderated models for testing);
- a non-numeric treatment (recode a factor to 0/1);
- an engine missingmed cannot run.

``` r

set_md_mediation(imp,
  formula_y = Y ~ treat + M + base + hard,
  formula_m = M ~ treat + base + hard,
  treatment = "treat", mediator = "M", engine = "lavaan"
)
#> Error:
#> ! `formula_y` and `formula_m` cannot be used with engine = "lavaan"; give the lavaan syntax in `model`.
```

In 0.5.0 an unsupported engine failed later, inside
[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md),
with an error from medfit. When a fit does fail, the error now names the
engine and the imputation
(`engine "glm" failed on imputation 3 of 10: ...`), and fitting warnings
are collected into one warning that lists the affected imputations.

### Arguments that do not apply are reported

``` r

r <- infer(fit, type = "mbco", level = 0.90)
#> Warning: Ignored for type = "mbco": `level`.
```

MBCO is a test, so it has no confidence level. In 0.5.0, `level` (and
`n.mc`, `treatment_level`) were silently ignored under `type = "mbco"`,
and a misspelled argument such as `conf.level = 0.9` was silently
dropped from a `"mc"` call, returning a 95% interval. Now the first case
warns and the second is an error:

``` r

infer(fit, type = "mc", conf.level = 0.90)
#> Error:
#> ! Unused argument in `infer()`: `conf.level`. The arguments are `type`, `level`, `n.mc`, `treatment_level` and, for an MDMediationFit, `ariv`.
```

### A treatment-by-mediator interaction

If the effect of the mediator on the outcome differs between arms, add
`treat:M` to the outcome model. The indirect effect is then
`a * (b + theta3 * x)`: it depends on the treatment level `x` at which
the mediator’s effect is evaluated.

``` r

fit_xm <- run(set_md_mediation(imp,
  formula_y = Y ~ treat * M + base + hard,
  formula_m = M ~ treat + base + hard,
  treatment = "treat", mediator = "M"
))
set.seed(3)
infer(fit_xm, type = "mc", treatment_level = 1)$CI
#>      2.5 %     97.5 % 
#> 0.03630311 0.19849593
set.seed(3)
infer(fit_xm, type = "mc", treatment_level = 0)$CI
#>      2.5 %     97.5 % 
#> 0.02329601 0.15239549
```

For a 0/1 treatment, `treatment_level = 1` gives the total natural
indirect effect and `0` the pure natural indirect effect. In these data
there is no true interaction, so the two intervals overlap heavily. In
0.5.0,
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md)
failed on such a model; `treatment_level` is required here so the
estimand is always stated.

### Sensitivity analysis with the MBCO test

[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)
can run the D4-MBCO test at every shift, and now passes `ariv` through
(0.5.0 always used `"fixed"`):

``` r

sens_mbco <- sensitivity_mnar(md, delta = c(0, -1, -2),
  type = "mbco", ariv = "fixed"
)
sens_mbco
#> <MDSensitivityResult>  MNAR sensitivity curve
#>   target(s): M | rungs: 3 | inference: mbco (ariv = "fixed") 
#>   seed: 2718 (from mids) | target imputed by: pmm 
#>   delta applied by: post (raw units) 
#> # A tibble: 3 × 6
#>       M    msp    D4 p_value mechanism scale
#>   <dbl>  <dbl> <dbl>   <dbl> <chr>     <chr>
#> 1     0  0.138  9.13 0.00275 post      raw  
#> 2    -1 -0.862  5.78 0.0169  post      raw  
#> 3    -2 -1.86   2.98 0.0852  post      raw  
#> 
#>   delta is a CONDITIONAL sensitivity parameter; `msp` is the marginal
#>   difference actually realized. Compare msp against what you intended.
#>   Assumes the supplied imputation model is compatible with the
#>   mediation model; this is not verifiable from here.
summary(sens_mbco)
#> MNAR sensitivity curve -- mbco | target: M 
#> 
#> # A tibble: 3 × 6
#>       M    msp    D4 p_value mechanism scale
#>   <dbl>  <dbl> <dbl>   <dbl> <chr>     <chr>
#> 1     0  0.138  9.13 0.00275 post      raw  
#> 2    -1 -0.862  5.78 0.0169  post      raw  
#> 3    -2 -1.86   2.98 0.0852  post      raw  
#> 
#> Tipping point: the smallest departure at which the null is
#>   retained is delta = -2 (realized msp = -1.8615 ).
#> A CSP-scale tipping point has no direct clinical reading -- judge
#> plausibility on the realized msp, and only call the result fragile if
#> that departure from MAR is itself plausible.
```

For an MBCO curve the null is retained at a shift when `p > 1 - level`.
If a rung fails to produce a result (an `NA` row),
[`summary()`](https://rdrr.io/r/base/summary.html) still reports the
tipping point when every such rung lies farther from MAR than it,
because those rungs cannot change the answer; otherwise it says the
tipping point is undetermined and names the rungs. In 0.5.0, any `NA`
rung made [`summary()`](https://rdrr.io/r/base/summary.html) fail.

## Summary

| Step | Function | Result |
|----|----|----|
| Describe the model | [`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md) | checked roles and formulas |
| Fit each imputation | [`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md) | per-imputation fits |
| Pool | [`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md) | Rubin’s-rules estimates |
| Interval | `infer(type = "mc")` | Monte Carlo CI for the indirect effect |
| Test | `infer(type = "mbco")` | D4-MBCO test of `a * b = 0` |
| Departures from MAR | [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md) | a sensitivity curve and tipping point |

See
[`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/dev/articles/mbco-mi.md)
for more on the D4-MBCO test and
[`vignette("technical")`](https://data-wise.github.io/missingmed/dev/articles/technical.md)
for the pooling details.
