# Cookbook

Short recipes for tasks that come up after the first analysis. Each is
self-contained given the data below, and each runs when the site builds.
For a guided introduction start with *Choosing an analysis*; for what
each engine supports, see the *Reference card*.

## The data used throughout

``` r

library(missingmed)
set.seed(1)
n <- 200
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n), W = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
dm <- d
dm$M[sample(n, 30)] <- NA                     # 15% of the mediator is missing
imp <- mice::mice(dm, m = 3, method = "norm", printFlag = FALSE, seed = 1)
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)
fit <- run(md)
```

(Three imputations keep the page fast; use 20 or more for a real
analysis.)

## 1. Test a latent mediator with MBCO

Give lavaan syntax and name the latent variable as the mediator. The
test fixes only the structural path, so each branch tests one parameter.

``` r

set.seed(51)
L <- 0.6 * d$X + rnorm(n)                      # the latent mediator
dl <- data.frame(
  X = d$X,
  m1 = L + rnorm(n, 0, 0.5), m2 = 0.8 * L + rnorm(n, 0, 0.5),
  m3 = 0.7 * L + rnorm(n, 0, 0.5)
)
dl$Y <- 0.2 * dl$X + 0.4 * L + rnorm(n)
dl$m1[sample(n, 30)] <- NA
imp_l <- mice::mice(dl, m = 3, method = "norm", printFlag = FALSE, seed = 2)

mbco_d4(mice::complete(imp_l, "all"),
  model = "Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ Ml + X",
  treatment = "X", mediator = "Ml", outcome = "Y"
)
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 3 imputations)
#>   D4 = 11.98 on F(1, 151.4), p = 0.0006998
#>   r4 = 0.1299 (ariv = "fixed") | d_S = 13.53 
#>   stacked constrained fit: a = 0 branch
#>   imputations on the a = 0 branch: 100% (not mixed)
```

## 2. Sweep a sensitivity analysis with MBCO

`type = "mbco"` returns one test per rung. Read it as a curve: if the
p-value crosses your threshold as `delta` grows, the conclusion depends
on the MAR assumption.

``` r

s <- sensitivity_mnar(md, delta = c(-0.5, 0, 0.5), type = "mbco", seed = 1)
tidy(s)
#> # A tibble: 3 × 6
#>       M     msp    D4 p_value mechanism scale
#>   <dbl>   <dbl> <dbl>   <dbl> <chr>     <chr>
#> 1  -0.5 -0.580   8.63 0.00333 post      raw  
#> 2   0   -0.0796  9.58 0.00199 post      raw  
#> 3   0.5  0.420  10.0  0.00156 post      raw
```

## 3. Test a moderated model

[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
refuses a model with a moderator it cannot interpret, but
[`mbco_d4()`](https://data-wise.github.io/missingmed/reference/mbco_d4.md)
runs the test on a plain list of completed data frames. A product term
with the mediator is dropped together with the mediator under the null.

``` r

mbco_d4(mice::complete(imp, "all"), Y ~ X + M * W, M ~ X + W,
  treatment = "X", mediator = "M"
)
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 3 imputations)
#>   D4 = 6.962 on F(1, 37.89), p = 0.01201
#>   r4 = 0.2983 (ariv = "fixed") | d_S = 9.039 
#>   stacked constrained fit: a = 0 branch
#>   imputations on the a = 0 branch: 100% (not mixed)
```

## 4. Put MI and IPW side by side

Both give a Monte Carlo interval for the indirect effect. IPW keeps the
complete cases and weights them; MI fills in the missing values.

``` r

md_ipw <- set_md_mediation(dm, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", method = "ipw"
)
set.seed(1)
rbind(
  MI  = unlist(infer(pool(fit), type = "mc", n.mc = 20000)[c("Estimate", "CI")]),
  IPW = unlist(infer(pool(run(md_ipw)), type = "mc", n.mc = 20000)[c("Estimate", "CI")])
)
#>      Estimate        CI1       CI2
#> MI  0.1204465 0.03069229 0.2433306
#> IPW 0.1198516 0.02382646 0.2538537
```

IPW has no MBCO test and no delta sensitivity analysis: it has no
imputations.

## 5. Move fitting options out of `run()`

Options belong in `fit_args` on
[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md).
Passing them through `run(...)` still works but warns (a lifecycle
deprecation warning, shown once per session).

``` r

# before: warns
fit <- run(md, m_star = 0)

# after
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", fit_args = list(m_star = 0)
)
fit <- run(md)
```

## 6. Read `branch_mix` and `ariv`

The test is the smaller of two likelihood-ratio statistics (the `a = 0`
and the `b = 0` branch). `branch_mix` says whether the imputations
disagreed about which branch was smaller. `ariv = "fixed"` tests every
imputation on the stacked data’s branch; `ariv = "own"` lets each
choose.

``` r

fixed <- infer(fit, type = "mbco", ariv = "fixed")
own <- infer(fit, type = "mbco", ariv = "own")
summ <- function(r) c(D4 = unname(r["D4"]), p = unname(r["p"]), mixed = r@branch_mix)
rbind(fixed = summ(fixed), own = summ(own))
#>             D4           p mixed
#> fixed 9.584559 0.001986522     0
#> own   9.584559 0.001986522     0
```

When the imputations agree (`mixed = 0`) the two are close. When they
disagree, prefer `"fixed"`: it tests one constraint with one `k`.

## 7. Recover from a refit that did not converge

An outcome that a predictor separates almost perfectly makes a logistic
refit fail, and the test refuses to return a p-value computed from it.
The message names the dataset, the branch and the model.

``` r

set.seed(2)
bad <- lapply(1:3, function(k) {
  x <- rnorm(100)
  m <- 0.5 * x + rnorm(100)
  data.frame(X = x, M = m, Y = as.integer(m > 0))   # Y is separated by M
})
mbco_d4(bad, Y ~ M + X, M ~ X,
  family_y = binomial(), treatment = "X", mediator = "M"
)
#> Warning: glm.fit: algorithm did not converge
#> Warning: glm.fit: fitted probabilities numerically 0 or 1 occurred
#> Error:
#> ! Fitting the MBCO models failed in imputation 1: the full outcome model did not converge. Rescale the variables or merge sparse factor levels; the data may be separated.
```

Rescale the variables, merge sparse factor levels, or simplify the
outcome model, then rerun.

## 8. Run a large simulation on a cluster

A calibration grid of hundreds of replications per cell does not belong
on a laptop. The repository’s `dev/` folder has the harness used to
check the lavaan MBCO: a per-task script (one cell and chunk per
`SLURM_ARRAY_TASK_ID`), an `sbatch` script, and a combiner. The pattern
to copy is to pilot through `sbatch` itself, not on the login node, then
submit the full array.

``` sh
# one task as a pilot, through the scheduler
sbatch --array=1 --export=ALL,REPS=8 dev/sim-sem-mbco-calibration.sbatch

# then the whole grid: 20 cells x 4 chunks
sbatch --array=1-80%20 dev/sim-sem-mbco-calibration.sbatch

# combine the per-task files
Rscript dev/sim-sem-mbco-combine.R "$SIM_OUT"
```
