# Inverse probability weighting, step by step

Multiple imputation fills in the missing values. Inverse probability
weighting (IPW) does something different: it keeps only the **complete
cases** and weights each one by the inverse of its estimated probability
of being observed, so the complete cases stand in for everyone.
missingmed runs both through the same
`set_md_mediation() -> run() -> pool() -> infer()` pipeline, selected by
`method`.

## Data with a missing mediator

Missingness in `M` depends on the covariate `C` (missing at random).

``` r

library(missingmed)
set.seed(1)
n <- 400
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
d$M[runif(n) < plogis(-1 + 0.8 * d$C)] <- NA
mean(is.na(d$M))
#> [1] 0.2975
```

## Fit

For IPW, `data` is the raw data frame (not a `mids` object), and
`method = "ipw"`.

``` r

md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", method = "ipw"
)
fit <- run(md)
res <- pool(fit)
res
#> <MDMediationResult> (pooled, Rubin's rules; m = 1 )
#>     term   estimate  std_error
#>        a 0.32014388 0.13465725
#>        b 0.30012919 0.05687859
#>  c_prime 0.01545917 0.12510767
#>   indirect effect a*b = 0.0961 
#>   -> infer(type = "mc") for the indirect-effect CI
```

There is one fit (`m = 1`), so the pooled table is that fit’s table,
with robust standard errors.

``` r

set.seed(2)
infer(fit, type = "mc", n.mc = 20000)
#> $CI
#> [1] 0.01502187 0.19289338
#> 
#> $Estimate
#> [1] 0.09593834
#> 
#> $SE
#> [1] 0.0453234
#> 
#> $MC.Error
#> [1] 0.0003204849
```

## Look at the weights

`fit@weights` has one entry per row of the data: the weight for a
complete case, `NA` for an incomplete one.

``` r

w <- fit@weights
c(complete = sum(!is.na(w)), incomplete = sum(is.na(w)))
#>   complete incomplete 
#>        281        119
summary(w)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.     NAs 
#>  0.7372  0.8633  0.9376  0.9957  1.0767  2.0570     119
```

A few very large weights dominate the fit. If the maximum is many times
the median, the missingness model has probabilities close to zero for
some cases and the estimate rests on them. Two remedies, both arguments
of
[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md):
`weight_trim` caps the weights, and a simpler `weight_formula` avoids
extreme probabilities.

## Choosing the missingness model

By default the missingness model uses every observed predictor.
`weight_formula` overrides it: a single formula, or a named list with
one formula per incomplete variable.

``` r

md2 <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", method = "ipw",
  weight_formula = list(M = ~ X + C)
)
summary(run(md2)@weights)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.     NAs 
#>  0.7375  0.8632  0.9375  0.9958  1.0796  2.1085     119
```

## Stabilizing and trimming

`weight_stabilize = TRUE` (the default) multiplies by the marginal
probability of being observed, which leaves the estimate’s target
unchanged and shrinks the weights’ spread. `weight_trim` is an upper
quantile: `0.95` caps the largest 5% of weights at the 95th percentile.
`1` (default) means no trimming.

``` r

md3 <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", method = "ipw", weight_trim = 0.95
)
rbind(
  untrimmed = summary(run(md)@weights)[c("Min.", "Median", "Max.")],
  trimmed   = summary(run(md3)@weights)[c("Min.", "Median", "Max.")]
)
#>                Min.    Median     Max.
#> untrimmed 0.7372171 0.9376321 2.057021
#> trimmed   0.7372171 0.9376321 1.357121
```

Trimming trades a little bias for less variance. Report whether you
trimmed.

## Standard errors

`se_type = "sandwich"` (default) uses a heteroskedasticity-robust (HC)
variance; `"model"` uses the usual model-based one, which is wrong for
weighted fits and is there for comparison only. The weights are treated
as **known**: the uncertainty from estimating them is not propagated.

## IPW or imputation?

Compare them on the same data.

``` r

imp <- mice::mice(d, m = 10, method = "norm", printFlag = FALSE, seed = 3)
mi <- pool(run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)))
ipw <- res
cmp <- function(r) setNames(r@tidy_table$estimate, r@tidy_table$term)[c("a", "b", "c_prime")]
round(rbind(MI = cmp(mi), IPW = cmp(ipw)), 3)
#>         a     b c_prime
#> MI  0.308 0.309   0.053
#> IPW 0.320 0.300   0.015
```

Both rely on the missing-at-random assumption. Imputation uses every row
and usually has smaller standard errors; IPW is simpler to describe and
does not need an imputation model for the mediator, but depends on the
missingness model and discards incomplete rows. When they disagree by
more than their standard errors, suspect a misspecified model on one
side.

## Limits

- [`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)
  is not available for `method = "ipw"`: delta adjustment shifts imputed
  values, and IPW has none.
- `infer(type = "mbco")` is not implemented for IPW. Use `type = "mc"`.
- `engine = "lavaan"` works with IPW, with robust standard errors only;
  see the *Structural equation models* article.
