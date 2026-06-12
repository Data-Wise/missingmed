# Getting started with missingmed

**missingmed** runs SEM-based mediation across multiply imputed datasets
and pools with Rubin’s rules. It is a thin orchestration layer: it
**fits** each imputation with
[medfit](https://data-wise.github.io/medfit/) and delegates
**inference** to [RMediation](https://data-wise.github.io/rmediation/).
The S7 pipeline is four verbs:

    set_md_mediation()  ->  run()  ->  pool()  ->  infer()
       MDMediationData    MDMediationFit  MDMediationResult   CI / MBCO

## A worked example

We simulate a simple mediation model `X -> M -> Y` with a confounder
`C`, impose some MAR missingness, and impute with `mice`.

``` r

library(missingmed)

set.seed(2026)
n <- 300
C <- rnorm(n)
X <- rbinom(n, 1, plogis(0.3 * C))
M <- 0.5 * X + 0.3 * C + rnorm(n)
Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
d <- data.frame(X = X, M = M, Y = Y, C = C)
d$M[sample(n, 45)] <- NA
d$Y[sample(n, 30)] <- NA

imp <- mice::mice(d, m = 20, method = "norm", printFlag = FALSE)
```

### 1. Specify the mediation model

[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
records the outcome and mediator formulas plus the treatment/mediator
roles.

``` r

md <- set_md_mediation(
  imp,
  formula_y = Y ~ X + M + C,
  formula_m = M ~ X + C,
  treatment = "X",
  mediator  = "M"
)
md
#> <MDMediationData>
#>   estimator (method): mi | mechanism: mar 
#>   imputations (m)   : 20 
#>   treatment / mediator: X / M 
#>   outcome model : Y ~ X + M + C 
#>   mediator model: M ~ X + C 
#>   engine: glm
```

### 2. Fit each imputation

[`run()`](https://data-wise.github.io/missingmed/reference/run.md) fits
every imputed dataset with
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
yielding a list of **named**
[`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html)
objects.

``` r

fit <- run(md)
fit
#> <MDMediationFit>
#>   per-imputation fits: 20 named medfit::MediationData
#>   engine: glm 
#>   per-imputation a*b: mean = 0.3469 (range 0.2684 to 0.4085 )
#>   -> pool() for Rubin's-rules estimates; infer() for CIs / MBCO
```

### 3. Pool with Rubin’s rules

[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
combines the per-imputation estimates and variance-covariance into a
single **named** pooled
[`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html).

``` r

res <- pool(fit)
summary(res)
#> Pooled mediation result (Rubin's rules)
#>   imputations (m): 20 | engine: glm 
#> 
#>           term    estimate  std_error       var_w        var_b     var_tot
#>  m_(Intercept) -0.16522317 0.08238139 0.005746617 0.0009905497 0.006786694
#>            m_X  0.93925967 0.11601493 0.012281822 0.0011215648 0.013459465
#>            m_C  0.28887608 0.06017413 0.003393052 0.0002170228 0.003620926
#>  y_(Intercept) -0.06574674 0.08649197 0.006525312 0.0009100461 0.007480860
#>            y_X  0.25996102 0.14419632 0.017044636 0.0035694682 0.020792577
#>            y_M  0.36924532 0.06955480 0.003766726 0.0010201381 0.004837871
#>            y_C  0.34579037 0.06714072 0.004105318 0.0003833889 0.004507877
#>              a  0.93925967 0.11601493 0.012281822 0.0011215648 0.013459465
#>              b  0.36924532 0.06955480 0.003766726 0.0010201381 0.004837871
#>        c_prime  0.25996102 0.14419632 0.017044636 0.0035694682 0.020792577
#> 
#>   a*b = 0.3468
```

### 4. Inference on the indirect effect

The Monte-Carlo / distribution-of-the-product CI is computed by
RMediation on the pooled object:

``` r

infer(res, type = "mc")
#> $CI
#> [1] 0.2040696 0.5107304
#> 
#> $Estimate
#> [1] 0.34706
#> 
#> $SE
#> [1] 0.07851401
#> 
#> $MC.Error
#> [1] 0.0002482831
```

For the **MBCO** likelihood-ratio test of `H0: a*b = 0`, use the fit
object (see
[`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md)
for why pooling does not commute with MBCO):

``` r

infer(fit, type = "mbco")
#>           D4            p           r4           nu          d_S 
#> 2.496516e+01 1.428789e-06 3.818416e-01 1.716563e+02 3.449790e+01
```

## Migrating from the S4 API

The S4 entry points
([`set_sem()`](https://data-wise.github.io/missingmed/reference/set_sem.md),
[`run_sem()`](https://data-wise.github.io/missingmed/reference/run_sem.md),
[`pool_sem()`](https://data-wise.github.io/missingmed/reference/pool_sem.md))
are **deprecated** in favour of the S7 verbs above. They still work for
one release cycle but emit a deprecation warning.
