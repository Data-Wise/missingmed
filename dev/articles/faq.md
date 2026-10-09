# Frequently asked questions

### `pool()` gives an error about `mira` objects, or does the wrong thing

`mice` also exports
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md).
Whichever package is attached last masks the other, so
[`library(mice)`](https://github.com/amices/mice) after
[`library(missingmed)`](https://github.com/Data-Wise/missingmed) makes
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md)
mean [`mice::pool()`](https://amices.org/mice/reference/pool.html). Call
[`mice::mice()`](https://amices.org/mice/reference/mice.html) with the
prefix instead of attaching `mice`, or call
[`missingmed::pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md).
The missingmed version forwards anything that is not a missingmed fit (a
[`mice::mira`](https://amices.org/mice/reference/mira.html), for
example) to
[`mice::pool()`](https://amices.org/mice/reference/pool.html), so it is
safe to keep missingmed’s
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md)
in front.

### Monte Carlo interval or MBCO test?

They answer different questions. `infer(type = "mc")` gives a confidence
interval for the indirect effect from the pooled estimates.
`infer(type = "mbco")` gives a likelihood-ratio test of $`H_0: ab = 0`$
and needs the per-imputation fits, so call it on the result of
[`run()`](https://data-wise.github.io/missingmed/dev/reference/run.md),
not of
[`pool()`](https://data-wise.github.io/missingmed/dev/reference/pool.md).
[`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/dev/articles/mbco-mi.md)
covers the test;
[`vignette("worked-analysis")`](https://data-wise.github.io/missingmed/dev/articles/worked-analysis.md)
uses both.

### Why does `infer()` ask for `treatment_level`?

The outcome model has a treatment-by-mediator interaction, so the
indirect effect is $`a (b + \theta_3 x)`$ and depends on the treatment
level $`x`$. missingmed does not pick $`x`$ for you. For a 0/1
treatment, `1` gives the total and `0` the pure natural indirect effect.
Section 3A of
[`vignette("technical")`](https://data-wise.github.io/missingmed/dev/articles/technical.md)
has the details.

### What does `ariv` do?

It applies to `infer(type = "mbco")` and
[`mbco_d4()`](https://data-wise.github.io/missingmed/dev/reference/mbco_d4.md).
With `ariv = "fixed"` (the default), every imputation’s likelihood ratio
is taken on the branch the stacked constrained fit chose ($`a = 0`$ or
$`b = 0`$). With `ariv = "own"`, each imputation uses its own winning
branch, which reproduces missingmed 0.4.0. The branch diagnostics are
properties of the returned `MbcoMIResult`.

### How many imputations do I need?

The pooled variance adds $`(1 + 1/m)B`$ to the within-imputation
variance, and the Monte Carlo error of everything computed across
imputations shrinks as $`m`$ grows. A practical check: rerun with a
larger `m` and a different seed, and see whether the conclusions move.
The `fmi` column of `pool(fit)@tidy_table` reports the fraction of
missing information per coefficient.

### My model has a moderator. Can I use it?

Not in
[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md),
which allows only main effects of the treatment and mediator plus one
`X:M` term (see the *Supported models* article).
[`mbco_d4()`](https://data-wise.github.io/missingmed/dev/reference/mbco_d4.md)
tests the indirect effect of a moderated model on a list of completed
datasets.

### Binary mediator or outcome?

Set `family_m = binomial()` or `family_y = binomial()`. The indirect
effect is then a product of coefficients on the link scale, not a
difference in probabilities; section 5A of
[`vignette("technical")`](https://data-wise.github.io/missingmed/dev/articles/technical.md)
explains the caveat.

### MI or IPW?

`method = "mi"` takes a `mids` object and pools across imputations.
`method = "ipw"` takes the raw data frame and reweights the complete
cases by the inverse probability of being complete, with sandwich
standard errors by default. MBCO is not available for IPW fits.

### What scale is `delta` in `sensitivity_mnar()` on?

The scale of the target variable’s imputation model: an additive shift
for a continuous target, a log-odds shift for a binary one. Section 5B.2
of
[`vignette("technical")`](https://data-wise.github.io/missingmed/dev/articles/technical.md)
shows how to translate a delta into a statement about non-respondents.

### Why does `infer()` warn that an argument was ignored?

Some arguments apply to one inference type only, such as `level`, `n.mc`
and `treatment_level` for `"mc"` and `ariv` for `"mbco"`. Passing one to
the other type warns, so a typo or a mismatched argument is not silently
dropped.

### Structural equation models and latent mediators?

Yes, since 0.6.0. The glm path fits regression models through medfit;
for a structural equation model, including a latent mediator, use
`set_md_mediation(engine = "lavaan")` with the lavaan syntax in `model`
and the `outcome` named. `infer(type = "mc")` and `infer(type = "mbco")`
both work for lavaan fits (MBCO with maximum likelihood only; it is
refused for `MLR`, `MLM`, `WLSMV`, `group`, `ordered` and
`sampling.weights`). See the *Structural equation models* article and
the *Migrating from the S4 API* article.

### Why does `run()` or `sensitivity_mnar()` warn that passing arguments is deprecated?

Since 0.7.0, fitting options belong in
[`set_md_mediation()`](https://data-wise.github.io/missingmed/dev/reference/set_md_mediation.md),
where they are stored on the object and reused by every later refit
(including the refits inside
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)).
Passing them through `run(...)` or `sensitivity_mnar(...)` still works
but warns, with class `md_dots_deprecated`. Move the argument:

``` r

# before (warns)
fit <- run(md, m_star = 0)

# after
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M", fit_args = list(m_star = 0)
)
fit <- run(md)
```

A name that is already in `fit_args` cannot also be passed through
`run(...)`; that is an error. For `engine = "lavaan"`, `fit_args` holds
options for [`lavaan::sem()`](https://rdrr.io/pkg/lavaan/man/sem.html).

### `infer(type = "mbco")` stopped with “model did not converge”

One of the refits behind the test did not converge, and a
likelihood-ratio statistic from a non-converged fit is not a likelihood
ratio, so the test stops rather than return a p-value. The message names
the dataset (an imputation, or the stacked data), the branch (`full`,
`a = 0` or `b = 0`) and the model (`mediator` or `outcome`). The usual
causes are a binary outcome that a predictor separates almost perfectly,
a sparse factor level, or variables on very different scales: rescale,
merge sparse levels, or simplify the model. A fit that converged but
carries glm’s “fitted probabilities numerically 0 or 1” warning is not
refused; treat its p-value with care. The *Reference card* lists the
other messages.

In
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/dev/reference/sensitivity_mnar.md)
the same failure stops the sweep at that rung, and the message names the
rung and its delta. To keep the rungs that worked, pass
`on_error = "continue"`: the failed rungs read as `NA`,
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) gains an
`error` column with each message, and a warning names them.

### How do I cite missingmed?

``` r

citation("missingmed")
```
