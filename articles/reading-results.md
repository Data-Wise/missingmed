# Reading the pooled results

[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
returns an `MDMediationResult`. This article reads its table column by
column, shows what
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
adds, and says what each number does and does not tell you.

``` r

library(missingmed)
set.seed(1)
n <- 300
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[runif(n) < plogis(-1 + 0.8 * d$C)] <- NA
imp <- mice::mice(d, m = 10, method = "norm", printFlag = FALSE, seed = 1)
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M",
  conf_int = TRUE, conf_level = 0.95
)
fit <- run(md)
res <- pool(fit)
```

## The table

``` r

tab <- res@tidy_table
names(tab)
#>  [1] "term"      "estimate"  "std_error" "var_w"     "var_b"     "var_tot"  
#>  [7] "statistic" "df"        "riv"       "fmi"       "p_value"   "conf_low" 
#> [13] "conf_high"
```

| Column | Meaning |
|----|----|
| `term` | Coefficient. The mediator model’s terms start `m_`, the outcome model’s `y_`; `a`, `b`, `c_prime` are the three path aliases. |
| `estimate` | Rubin’s pooled point estimate: the mean over imputations. |
| `std_error` | Square root of the total variance. |
| `var_w`, `var_b`, `var_tot` | Within-imputation, between-imputation and total variance, with `var_tot = var_w + (1 + 1/m) var_b`. |
| `statistic` | `estimate / std_error`. |
| `df` | Degrees of freedom for the reference distribution (below). |
| `riv` | Relative increase in variance due to missing data. |
| `fmi` | Fraction of missing information. |
| `p_value` | Two-sided p-value on that reference distribution. |
| `conf_low`, `conf_high` | Only if `conf_int = TRUE`, at `conf_level`. |

``` r

tab[tab$term %in% c("a", "b", "c_prime"),
  c("term", "estimate", "std_error", "df", "riv", "fmi", "p_value", "conf_low", "conf_high")]
#>       term  estimate  std_error        df        riv        fmi      p_value
#> 8        a 0.5602894 0.14131067  92.84715 0.31316611 0.25437198 0.0001442104
#> 9        b 0.2361358 0.07648787  41.60542 0.68334320 0.43258012 0.0035886095
#> 10 c_prime 0.2743249 0.13370846 247.19972 0.06559857 0.06906183 0.0412560350
#>      conf_low conf_high
#> 8  0.27966833 0.8409105
#> 9  0.08173363 0.3905380
#> 10 0.01097174 0.5376780
```

## Degrees of freedom

With more than one imputation the reference is Student’s *t* with the
Barnard–Rubin degrees of freedom. It uses the complete-data degrees of
freedom of the model the coefficient belongs to (`n_obs` minus the
number of that model’s terms), so a small sample is not treated as an
infinite one. For binomial and Poisson models, and for lavaan fits, the
complete-data degrees of freedom are infinite and the reference is a
large-sample *t* (with `m > 1`) or a normal (with `m = 1`).

With a single fit (`m = 1`) there is no between-imputation variance:
`riv` and `fmi` are zero and `df` is the complete-data value, so the
table is the ordinary Wald table of that fit.

## `riv` and `fmi`

`riv` is how much larger the variance is because of the missing data;
`fmi` is the share of the total information that is missing. Large
values (say `fmi` above 0.5) mean the answer leans heavily on the
imputation model. They are estimated from `m` imputations and are noisy
for small `m`: with `m = 5`, treat them as rough.

``` r

round(range(tab$fmi), 3)
#> [1] 0.069 0.689
```

## Confidence intervals of single coefficients

`conf_low` and `conf_high` bound **one coefficient** on Rubin’s *t*
reference. They are not an interval for the indirect effect, which is a
product of two coefficients and is not normally distributed.

## The indirect effect: `infer()`

``` r

set.seed(2)
mc <- infer(res, type = "mc", n.mc = 20000)
mc
#> $CI
#> [1] 0.03903793 0.25604568
#> 
#> $Estimate
#> [1] 0.132323
#> 
#> $SE
#> [1] 0.05581184
#> 
#> $MC.Error
#> [1] 0.0003946493
```

`type = "mc"` draws from the pooled distribution of `(a, b)` and reports
the percentile interval of `a * b` (via RMediation). `$CI` is the
interval, `$Estimate` the point estimate, `$SE` the Monte Carlo standard
error of the product, and `$MC.Error` the simulation error: raise `n.mc`
to shrink it.

`level` defaults to the `conf_level` you set on the data object; an
explicit `level =` in
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
wins.

## A test instead of an interval

The D4-stacked MBCO test needs the per-imputation fits, so call it on
the fit, not on the pooled result:

``` r

mb <- infer(fit, type = "mbco")
mb
#> <MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m = 10 imputations)
#>   D4 = 8.071 on F(1, 20.61), p = 0.009904
#>   r4 = 0.9456 (ariv = "fixed") | d_S = 15.7 
#>   stacked constrained fit: b = 0 branch
#>   imputations on the a = 0 branch: 30% (mixed)
```

`mb["p"]` is the p-value, `mb["D4"]` the statistic, `mb["nu"]` its
denominator degrees of freedom. See the *Testing an indirect effect*
article.

## What is not in the table

- A p-value for the **indirect effect** itself: use
  [`infer()`](https://data-wise.github.io/missingmed/reference/infer.md).
- A test of the missing-at-random assumption: none exists, and
  missingmed does not pretend to give one.
  [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
  shows how far a conclusion moves when MAR fails.
- For lavaan fits, the variance and covariance rows (`~~`) have `NA`
  statistic and p-value by design; see the *Structural equation models*
  article.
