# MBCO under multiple imputation (D4-stacked)

## Why MBCO does not commute with Rubin’s rules

The **model-based constrained optimization** (MBCO) test of mediation
tests $`H_0: a b = 0`$. Because $`a b = 0`$ iff $`a = 0`$**or**
$`b = 0`$, the constrained log-likelihood is a **branch union** — the
better of the “drop the a-path” and “drop the b-path” fits:

``` math
T = 2\left[\ell_{\text{full}} - \max(\ell_{a=0},\, \ell_{b=0})\right].
```

That [`max()`](https://rdrr.io/r/base/Extremes.html) is non-linear, so
the MBCO statistic of the *pooled* estimate is **not** the pool of the
per-imputation MBCO statistics. You cannot pool first and test second.
Instead, missingmed keeps every per-imputation fit (exposed by
[`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md))
and combines the **likelihood-ratio statistics** with the **D4** rule
(Chan & Meng, 2022; Grund, Lüdtke & Robitzsch, 2021):

``` math
d_S = \frac{\text{LRT(stacked data)}}{K}, \quad
r_4 = \max\!\left(0, \tfrac{K+1}{k(K-1)}(\bar d - d_S)\right), \quad
D_4 = \frac{d_S}{k(1 + r_4)} \sim F_{k,\nu}.
```

## In practice

``` r

library(missingmed)

set.seed(2026)
n <- 300
C <- rnorm(n)
X <- rbinom(n, 1, plogis(0.3 * C))
M <- 0.39 * X + 0.3 * C + rnorm(n)
Y <- 0.2 * X + 0.0 * M + 0.3 * C + rnorm(n) # interior null: b = 0
d <- data.frame(X = X, M = M, Y = Y, C = C)
d$M[sample(n, 45)] <- NA
d$Y[sample(n, 30)] <- NA

imp <- mice::mice(d, m = 20, method = "norm", printFlag = FALSE)
fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"))

infer(fit, type = "mbco", ariv = "fixed")
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 20 imputations)
#>   D4 = 0.1746 on F(1, 455), p = 0.6763
#>   r4 = 0.1996 (ariv = "fixed") | d_S = 0.2094 
#>   stacked constrained fit: b = 0 branch
#>   imputations on the a = 0 branch: 0% (not mixed)
```

## Which branch feeds $`r_4`$: the `ariv` argument

Each imputation’s statistic has its own winning branch, and the
imputations need not agree. `ariv` decides which statistics enter
$`\bar d`$, and so $`r_4`$:

- `ariv = "fixed"` (the default) recomputes every imputation’s statistic
  on the branch the **stacked** constrained fit chose. All imputations
  then test the same constraint, with the same $`k`$.
- `ariv = "own"` uses each imputation’s own winning branch, the standard
  Chan & Meng $`r_4`$. It reproduces missingmed 0.4.0, and it refuses to
  pool when the winning branches remove different numbers of parameters
  (for example, with an `X:M` term in the outcome model).

The result records the branch diagnostics:

``` r

r_fixed <- infer(fit, type = "mbco", ariv = "fixed")
r_fixed@stacked_branch # "a" (a = 0) or "b" (b = 0)
#> [1] "b"
r_fixed@branch_mix # do the imputations disagree on their own branch?
#> [1] FALSE
r_fixed@p_branch_a # share of imputations whose own branch is a = 0
#> [1] 0
tidy(r_fixed)
#> # A tibble: 1 × 12
#>   term     statistic   df1   df2 p_value    r4   d_S ariv  stacked_branch
#>   <chr>        <dbl> <dbl> <dbl>   <dbl> <dbl> <dbl> <chr> <chr>         
#> 1 indirect     0.175     1  455.   0.676 0.200 0.209 fixed b             
#> # ℹ 3 more variables: branch_mix <lgl>, p_branch_a <dbl>, m <int>
```

When no imputation disagrees with the stacked fit, the two agree.
Reporting the diagnostics needs both single-path null fits in every
imputation, which is why each imputation is fit three times.

The same test runs on any list of completed data frames, without the
pipeline:

``` r

implist <- mice::complete(imp, "all")
mbco_d4(implist, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", ariv = "fixed"
)
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 20 imputations)
#>   D4 = 0.1746 on F(1, 455), p = 0.6763
#>   r4 = 0.1996 (ariv = "fixed") | d_S = 0.2094 
#>   stacked constrained fit: b = 0 branch
#>   imputations on the a = 0 branch: 0% (not mixed)
```

The per-imputation fits MBCO needs are available directly:

``` r

acc <- per_imputation_list(fit)
acc$m
#> [1] 20
length(acc$per_imputation)
#> [1] 20
```

Asking for MBCO on the *pooled* result is an error by design:

``` r

infer(pool(fit), type = "mbco")
#> Error:
#> ! MBCO does not commute with Rubin's rules; it needs the per-imputation fits. Call infer(type = "mbco") on the MDMediationFit from run(), not on the pooled MDMediationResult.
```

## References

- Chan, K. W., & Meng, X.-L. (2022). Multiple improvements of multiple
  imputation likelihood ratio tests. *Statistica Sinica*.
- Grund, S., Lüdtke, O., & Robitzsch, A. (2021). Pooling methods for
  likelihood-ratio tests with multiply imputed data. *Psychological
  Methods*.
