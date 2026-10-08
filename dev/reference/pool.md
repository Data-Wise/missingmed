# Pool per-imputation mediation fits with Rubin's rules

Applies Rubin's (1987) rules to the list of per-imputation **named**
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
objects in an
[MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md),
producing a single pooled named
[medfit::MediationData](https://data-wise.github.io/medfit/reference/MediationData.html)
(the `pooled` slot of the returned
[MDMediationResult](https://data-wise.github.io/missingmed/dev/reference/MDMediationResult.md)).
Because the estimates and variance-covariance carry the mediation path
names (`a`, `b`, `c_prime`, ...), the pooled object is valid input to
[`RMediation::ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html)
/
[`RMediation::medci()`](https://data-wise.github.io/rmediation/reference/medci.html).
For a model with a treatment-by-mediator interaction, use
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md)`(type = "mc", treatment_level = )`
instead: those RMediation functions use only \\a b\\, the indirect
effect at treatment level 0.

## Usage

``` r
pool(object, ...)
```

## Arguments

- object:

  An
  [MDMediationFit](https://data-wise.github.io/missingmed/dev/reference/MDMediationFit.md)
  object. Anything else (a
  [`mice::mira`](https://amices.org/mice/reference/mira.html), say) is
  forwarded to
  [`mice::pool()`](https://amices.org/mice/reference/pool.html).

- ...:

  Unused.

## Value

An
[MDMediationResult](https://data-wise.github.io/missingmed/dev/reference/MDMediationResult.md)
object.

## Details

Pooling math (migrated from the S4 `pool_sem` / `pool_tidy` /
`pool_cov`): \$\$\bar Q = \frac{1}{m}\sum_i Q_i, \quad \bar U =
\frac{1}{m}\sum_i U_i, \quad B = \mathrm{cov}(Q_1, \ldots, Q_m), \quad T
= \bar U + (1 + 1/m) B.\$\$

It is the S7 successor of the S4
[`pool_sem()`](https://data-wise.github.io/missingmed/dev/reference/missingmed-defunct.md)
method.

The returned tidy table also carries a per-coefficient Wald test
(`statistic`, `df`, `riv`, `fmi`, `p_value`) and, when `conf_int = TRUE`
was set in
[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md),
per-coefficient `conf_low` and `conf_high` at `conf_level` on the same t
reference; see
[MDMediationResult](https://data-wise.github.io/missingmed/dev/reference/MDMediationResult.md)
for the columns and why they do not test or bound the indirect effect.

## References

Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in Surveys*.
Wiley.

Barnard, J., & Rubin, D. B. (1999). Small-sample degrees of freedom with
multiple imputation. *Biometrika*, 86(4), 948–955.

## See also

[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md),
[`infer()`](https://data-wise.github.io/missingmed/dev/reference/infer.md),
[`pool_sem()`](https://data-wise.github.io/missingmed/dev/reference/missingmed-defunct.md)

## Examples

``` r
set.seed(1)
n <- 150
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[sample(n, 25)] <- NA
imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, conf_int = TRUE,
  treatment = "X", mediator = "M"
)
res <- pool(run(md))
res
#> <MDMediationResult> (pooled, Rubin's rules; m = 3 )
#>     term  estimate std_error
#>        a 0.2997036 0.2373242
#>        b 0.1184713 0.1078543
#>  c_prime 0.4906530 0.1858024
#>   indirect effect a*b = 0.0355 
#>   -> infer(type = "mc") for the indirect-effect CI
# Per-coefficient table, with Rubin's df and conf_low/conf_high
res@tidy_table[, c("term", "estimate", "std_error", "df", "conf_low", "conf_high")]
#>             term   estimate std_error         df   conf_low conf_high
#> 1  m_(Intercept)  0.1913439 0.1387452  13.479078 -0.1073176 0.4900054
#> 2            m_X  0.2997036 0.2373242   5.921504 -0.2828789 0.8822861
#> 3            m_C  0.4581555 0.0982157  18.924013  0.2525318 0.6637792
#> 4  y_(Intercept) -0.1428326 0.1287487 141.503020 -0.3973521 0.1116869
#> 5            y_X  0.4906530 0.1858024 130.680441  0.1230833 0.8582228
#> 6            y_M  0.1184713 0.1078543  26.045872 -0.1032073 0.3401499
#> 7            y_C  0.4293115 0.1052909 127.927068  0.2209744 0.6376486
#> 8              a  0.2997036 0.2373242   5.921504 -0.2828789 0.8822861
#> 9              b  0.1184713 0.1078543  26.045872 -0.1032073 0.3401499
#> 10       c_prime  0.4906530 0.1858024 130.680441  0.1230833 0.8582228
```
