# Technical reference: design, contracts, and methodology

This vignette is the single technical reference for **missingmed**: the
architecture, the cross-package contracts it depends on, the statistical
methodology of every estimator and inference path, and the engineering
decisions (and their rationale) made along the way. Code blocks are
illustrative (`eval = FALSE`); runnable walkthroughs live in
[`vignette("missingmed")`](https://data-wise.github.io/missingmed/articles/missingmed.md)
and
[`vignette("mbco-mi")`](https://data-wise.github.io/missingmed/articles/mbco-mi.md).

------------------------------------------------------------------------

## 1. Architecture (S7, four verbs, three classes)

missingmed is a **thin orchestration layer**: it runs mediation across
the “missing-data middle” and delegates the statistics outward —
**fitting** to [medfit](https://data-wise.github.io/medfit/),
**inference** to [RMediation](https://data-wise.github.io/rmediation/),
and (later) simulation to medsim. It is written in **S7** to match the
newer ecosystem packages and the shared
[`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html)
contract.

The pipeline is four verbs over three classes:

    set_md_mediation()  ->  run()          ->  pool()             ->  infer()
       MDMediationData       MDMediationFit     MDMediationResult      CI / MBCO
       (data + spec)         (per-imputation    (pooled named          (RMediation
                              named Med.Data)    Med.Data)              or hosted D4)

The same pipeline as a diagram:

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA4ODAgMjI1IiB3aWR0aD0iMTAwJSIgcm9sZT0iaW1nIiBhcmlhLWxhYmVsPSJtaXNzaW5nbWVkIHBpcGVsaW5lOiBzZXRfbWRfbWVkaWF0aW9uIHRvIHJ1biB0byBwb29sIHRvIGluZmVyIj48dGl0bGU+Cm1pc3NpbmdtZWQgcGlwZWxpbmUKPC90aXRsZT4KPGRlZnM+PG1hcmtlciBpZD0iYWgiIHZpZXdib3g9IjAgMCAxMCAxMCIgcmVmeD0iOSIgcmVmeT0iNSIgbWFya2Vyd2lkdGg9IjciIG1hcmtlcmhlaWdodD0iNyIgb3JpZW50PSJhdXRvLXN0YXJ0LXJldmVyc2UiPjxwYXRoIGQ9Ik0wLDAgTDEwLDUgTDAsMTAgeiIgZmlsbD0iIzQ0NCIgLz48L21hcmtlcj48L2RlZnM+PGcgZm9udC1mYW1pbHk9Ii1hcHBsZS1zeXN0ZW0sU2Vnb2UgVUksSGVsdmV0aWNhLEFyaWFsLHNhbnMtc2VyaWYiPjxyZWN0IHg9IjE1IiB5PSIzMCIgd2lkdGg9IjE2MCIgaGVpZ2h0PSI1MiIgcng9IjciIGZpbGw9IiNlZWY0ZmIiIHN0cm9rZT0iIzRhNzZhOCIgc3Ryb2tlLXdpZHRoPSIxLjQiIC8+PHRleHQgeD0iOTUuMCIgeT0iNTEiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzFiMmIzYSI+TURNZWRpYXRpb25EYXRhPC90ZXh0Pjx0ZXh0IHg9Ijk1LjAiIHk9IjY4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEwLjUiIGZpbGw9IiM1YTZiN2EiPmRhdGEKKyBzcGVjPC90ZXh0PjxyZWN0IHg9IjI0NSIgeT0iMzAiIHdpZHRoPSIxNjAiIGhlaWdodD0iNTIiIHJ4PSI3IiBmaWxsPSIjZWVmNGZiIiBzdHJva2U9IiM0YTc2YTgiIHN0cm9rZS13aWR0aD0iMS40IiAvPjx0ZXh0IHg9IjMyNS4wIiB5PSI1MSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMWIyYjNhIj5NRE1lZGlhdGlvbkZpdDwvdGV4dD48dGV4dCB4PSIzMjUuMCIgeT0iNjgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iIzVhNmI3YSI+bQpuYW1lZCBNZWRpYXRpb25EYXRhPC90ZXh0PjxyZWN0IHg9IjQ3NSIgeT0iMzAiIHdpZHRoPSIxNjAiIGhlaWdodD0iNTIiIHJ4PSI3IiBmaWxsPSIjZWVmNGZiIiBzdHJva2U9IiM0YTc2YTgiIHN0cm9rZS13aWR0aD0iMS40IiAvPjx0ZXh0IHg9IjU1NS4wIiB5PSI1MSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMi41IiBmb250LXdlaWdodD0iNjAwIiBmaWxsPSIjMWIyYjNhIj5NRE1lZGlhdGlvblJlc3VsdDwvdGV4dD48dGV4dCB4PSI1NTUuMCIgeT0iNjgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iIzVhNmI3YSI+cG9vbGVkCk1lZGlhdGlvbkRhdGE8L3RleHQ+PHJlY3QgeD0iNzA1IiB5PSIzMCIgd2lkdGg9IjE2MCIgaGVpZ2h0PSI1MiIgcng9IjciIGZpbGw9IiNlZWY0ZmIiIHN0cm9rZT0iIzRhNzZhOCIgc3Ryb2tlLXdpZHRoPSIxLjQiIC8+PHRleHQgeD0iNzg1LjAiIHk9IjUxIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEyLjUiIGZvbnQtd2VpZ2h0PSI2MDAiIGZpbGw9IiMxYjJiM2EiPlJNZWRpYXRpb248L3RleHQ+PHRleHQgeD0iNzg1LjAiIHk9IjY4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjEwLjUiIGZpbGw9IiM1YTZiN2EiPmNpX21lZGlhdGlvbl9kYXRhKCk8L3RleHQ+PHJlY3QgeD0iMjQ1IiB5PSIxNTAiIHdpZHRoPSIxNjAiIGhlaWdodD0iNTIiIHJ4PSI3IiBmaWxsPSIjZmRmM2U3IiBzdHJva2U9IiNjOThhM2MiIHN0cm9rZS13aWR0aD0iMS40IiAvPjx0ZXh0IHg9IjMyNS4wIiB5PSIxNzEiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTIuNSIgZm9udC13ZWlnaHQ9IjYwMCIgZmlsbD0iIzFiMmIzYSI+aG9zdGVkCkQ0PC90ZXh0Pjx0ZXh0IHg9IjMyNS4wIiB5PSIxODgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iIzVhNmI3YSI+Ui9tYmNvX21pLlI8L3RleHQ+PHBhdGggZD0iTTE3NSw1NiBMMjQwLDU2IiBzdHJva2U9IiM0NDQiIHN0cm9rZS13aWR0aD0iMS40IiBmaWxsPSJub25lIiBtYXJrZXItZW5kPSJ1cmwoI2FoKSIgLz48dGV4dCB4PSIyMDciIHk9IjUwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIiBmb250LXN0eWxlPSJpdGFsaWMiPnJ1bigpPC90ZXh0PjxwYXRoIGQ9Ik00MDUsNTYgTDQ3MCw1NiIgc3Ryb2tlPSIjNDQ0IiBzdHJva2Utd2lkdGg9IjEuNCIgZmlsbD0ibm9uZSIgbWFya2VyLWVuZD0idXJsKCNhaCkiIC8+PHRleHQgeD0iNDM3IiB5PSI1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyIgZm9udC1zdHlsZT0iaXRhbGljIj5wb29sKCk8L3RleHQ+PHBhdGggZD0iTTYzNSw1NiBMNzAwLDU2IiBzdHJva2U9IiM0NDQiIHN0cm9rZS13aWR0aD0iMS40IiBmaWxsPSJub25lIiBtYXJrZXItZW5kPSJ1cmwoI2FoKSIgLz48dGV4dCB4PSI2NjciIHk9IjUwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXNpemU9IjExIiBmaWxsPSIjMzMzIiBmb250LXN0eWxlPSJpdGFsaWMiPmluZmVyKCZxdW90O21jJnF1b3Q7KTwvdGV4dD48cGF0aCBkPSJNMzI1LDgyIEwzMjUsMTUwIiBzdHJva2U9IiM0NDQiIHN0cm9rZS13aWR0aD0iMS40IiBmaWxsPSJub25lIiBtYXJrZXItZW5kPSJ1cmwoI2FoKSIgLz48dGV4dCB4PSIzMzUiIHk9IjEyMCIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzMzMyIgZm9udC1zdHlsZT0iaXRhbGljIj5pbmZlcijigJxtYmNv4oCdKTwvdGV4dD48dGV4dCB4PSIxNSIgeT0iMjA1IiBmb250LXNpemU9IjEwLjUiIGZpbGw9IiM1YTZiN2EiPk5vdGU6IGluZmVyKOKAnG1j4oCdKQpjb25zdW1lcyB0aGUgcG9vbGVkIHJlc3VsdDsgaW5mZXIo4oCcbWJjb+KAnSkgcmVhY2hlcyBiYWNrIHRvIHRoZQpwZXItaW1wdXRhdGlvbiBmaXQgKHNlY3Rpb24gNC4xKS48L3RleHQ+PC9nPjwvc3ZnPg==)

Note the asymmetry the linear sketch above cannot show:
`infer(type = "mc")` consumes the **pooled** result, while
`infer(type = "mbco")` reaches back to the **per-imputation** fit. That
is section 4.1’s non-commutativity, drawn.

A A\[“set_md_mediation()  
MDMediationData”\] –\>\|“method = mi”\| R1\[“run()  
fit each imputation”\] A –\>\|“method = ipw”\| R2\[“run()  
reweight complete cases”\] R1 –\> F\[“MDMediationFit  
list of m named MediationData”\] R2 –\> F F –\>\|“pool()”\|
P\[“MDMediationResult  
pooled named MediationData”\] P –\>\|“infer(type = mc)”\|
C1\[“RMediation::ci_mediation_data()”\] F –\>\|“infer(type = mbco)”\|
C2\[“hosted D4 stacking  
R/mbco_mi.R”\] –\>

| S7 class | Carries | S4 ancestor |
|----|----|----|
| `MDMediationData` | data (`mids` or `data.frame`) + mediation spec + estimator/mechanism axes | `SemImputedData` |
| `MDMediationFit` | **list** of per-imputation named [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html) (+ IPW `weights`) | `SemResults` |
| `MDMediationResult` | **pooled** named [`medfit::MediationData`](https://data-wise.github.io/medfit/reference/MediationData.html) + within/between/total vcov | `PooledSEMResults` |

**Orthogonal axes.** The estimator (`method = "mi" | "ipw"`) and the
model (formulas + `engine`) are independent. The same
`run() -> pool() -> infer()` chain serves both estimators; only
[`run()`](https://data-wise.github.io/missingmed/reference/run.md)
branches internally.

``` r

md <- set_md_mediation(data, formula_y = Y ~ X + M + C, formula_m = M ~ X + C,
  treatment = "X", mediator = "M", method = "mi")   # or method = "ipw"
res <- pool(run(md))
infer(res, type = "mc")
```

------------------------------------------------------------------------

## 2. Ecosystem contracts

missingmed produces and consumes objects defined elsewhere. These
contracts are load-bearing — getting the **names** right is what makes
inference work.

### 2.1 `medfit::MediationData` (the fitting contract)

`fit_mediation()` / `extract_mediation()` return a `MediationData` whose
`@estimates` is a **named** numeric vector and `@vcov` a **named**
matrix:

    estimates: m_(Intercept), m_X, m_C, y_(Intercept), y_X, y_M, y_C, a, b, c_prime

The convenience aliases `a` (= `m_X`), `b` (= `y_M`), `c_prime` (=
`y_X`) and the matching `@vcov` dimnames are the interface every
downstream consumer resolves **by name**.

### 2.2 `RMediation` (the inference contract)

> **Namespace note:** the package is `RMediation` (capital R-M), *not*
> `rmediation` — the source repo is `data-wise/rmediation` but
> `DESCRIPTION: Package: RMediation`. Code uses `RMediation::`.

- `ci_mediation_data(mu, level, type, n.mc)` — Monte-Carlo /
  distribution-of-the- product CI from a **single named**
  `MediationData`. Resolves `a`/`b` strictly by name (errors if
  unnamed). This is the `type = "mc"` path.
- `mbco(h0, h1, ...)` — likelihood-ratio MBCO, currently
  **OpenMx-only**; it has no per-imputation / MI entry point (see §4).

### 2.3 Dependency direction (no cycle)

    missingmed  ->  medfit       (fit_mediation, MediationData)
    missingmed  ->  RMediation   (ci_mediation_data, medci)
    RMediation  ->  medfit       (consumes MediationData)
    medsim          (Suggests, later phases)

missingmed imports both medfit and RMediation; neither depends back on
missingmed, so the graph is acyclic.

------------------------------------------------------------------------

## 3. The MI estimator and Rubin’s rules

Under multiple imputation,
[`run()`](https://data-wise.github.io/missingmed/reference/run.md) fits
**every** imputed dataset with
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
yielding a list of `m` named `MediationData`.
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
applies Rubin’s (1987) rules on the **named** vectors so the path labels
survive pooling:

``` math
\bar Q = \tfrac1m\sum_i Q_i,\quad
\bar U = \tfrac1m\sum_i U_i,\quad
B = \tfrac{1}{m-1}\sum_i (Q_i-\bar Q)(Q_i-\bar Q)^\top,\quad
T = \bar U + \left(1+\tfrac1m\right)B .
```

#### Worked example: pooling three imputations

*Time: about 3 minutes. Arithmetic only – no calculus, no software.*

**After this you can** compute $`T`$ by hand and say what fraction of
your information the missing data cost you.

**The punchline first.** Three imputations whose estimates differ by
only $`\pm 0.10`$ turn a standard error of 0.100 into **0.153**. That
53% inflation *is* the price of the missing data, and computing it is
all [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
does.

Symbols in this example:

| symbol  | plain words                        | here                         |
|---------|------------------------------------|------------------------------|
| $`Q_i`$ | the estimate from imputation $`i`$ | $`\hat a_i`$                 |
| $`U_i`$ | how uncertain that single fit was  | $`0.01`$, i.e. $`SE = 0.10`$ |
| $`B`$   | how much the imputations disagreed | computed in step 3           |
| $`T`$   | total variance, both sources       | computed in step 4           |

The three fits:

| $`i`$ | $`Q_i = \hat a_i`$ | $`U_i`$ | $`Q_i - \bar Q`$ |
|-------|--------------------|---------|------------------|
| 1     | 0.50               | 0.01    | -0.10            |
| 2     | 0.60               | 0.01    | 0.00             |
| 3     | 0.70               | 0.01    | +0.10            |

**Step 1 – average the estimates.**
$`\bar Q = \tfrac{0.50+0.60+0.70}{3} = \mathbf{0.60}`$

**Step 2 – average the within-imputation variances.**
$`\bar U = \tfrac{0.01+0.01+0.01}{3} = \mathbf{0.01}`$

**Step 3 – measure the disagreement between imputations.**
$`B = \tfrac{1}{3-1}\big[(-0.10)^2 + 0^2 + (0.10)^2\big]
= \tfrac{0.02}{2} = \mathbf{0.01}`$

**Step 4 – combine the two sources.**
$`T = \bar U + \left(1+\tfrac13\right)B = 0.01 + \tfrac43(0.01)
= \mathbf{0.0233\overline{3}}`$, so $`SE = \sqrt{T} = \mathbf{0.1528}`$.

Two more numbers fall straight out:

- **Fraction of missing information**
  $`\gamma = (1+\tfrac1m)B/T = 0.01\overline{3}/0.023\overline{3} =
  \mathbf{0.571}`$. Over half the information about $`a`$ is missing.
- **Degrees of freedom**
  $`\nu = (m-1)\big(1 + \bar U/[(1+\tfrac1m)B]\big)^2 = 2(1+0.75)^2 =
  \mathbf{6.125}`$. Three imputations buy about six df, not three.

![Stacked bar: total variance T splits into a within-imputation part
0.010 and a between-imputation part 0.0133; the standard error rises
from 0.100 to 0.153.](technical_files/figure-html/rubin-decomp-1.png)

**Explain this one to yourself before moving on.** Step 4 multiplies
$`B`$ by $`(1+\tfrac1m)`$ instead of using $`B`$ alone. Why should a
*larger* $`m`$ make that correction *smaller*?

Answer

$`B`$ is itself estimated, from only $`m`$ numbers, so it carries
sampling error of its own. The $`(1+\tfrac1m)`$ factor inflates it to
account for that. With $`m = 3`$ the factor is $`4/3`$; with $`m = 100`$
it is $`1.01`$. The more imputations you draw, the better you know the
between-imputation variance, and the less you must pad it.

![The correction factor 1 + 1/m falls from 1.5 at m = 2 toward 1 as m
grows, with m = 3, 10 and 20
marked.](technical_files/figure-html/correction-vs-m-1.png)

**Your turn – same four steps, one line blanked.** Now
$`Q = (0.20,\ 0.30,\ 0.40)`$, still with $`U_i = 0.01`$ and $`m = 3`$.
$`\bar Q = 0.30`$; \$B = \underline{\hphantom{0.01}}\$; \$T =
\underline{\hphantom{0.0233}}\$.

Filled in

The spacing is identical to the worked case, so the deviations are again
$`(-0.10, 0, +0.10)`$: $`B = 0.02/2 = 0.01`$ and
$`T = 0.01 + \tfrac43(0.01) = 0.0233\overline{3}`$, $`SE = 0.1528`$.
Only $`\bar Q`$ moved. **$`T`$ depends on the *spread* of the
imputations, never on their level.**

> **Why this cannot be done on $`\hat a\hat b`$ directly.** Every step
> above is linear in $`Q`$. The indirect effect $`ab`$ is not, so
> [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
> deliberately stops here: it pools $`(a, b)`$ and their covariance and
> hands the nonlinear step to `RMediation`. Pooling
> $`\hat a_i \hat b_i`$ across imputations and attaching a normal
> interval commits two errors at once.

**You can now** read `res@tidy_table`’s `var_w`, `var_b` and `var_tot`
columns as steps 2, 3 and 4 of the arithmetic above.

The table also carries a Rubin-pooled Wald test for each coefficient:
`statistic`, `df`, `riv`, `fmi` and `p_value`. `df` is the Barnard–Rubin
(1999) small-sample df, using each model’s complete-data df. The
mediator model’s df applies to the `m_*` rows and the outcome model’s to
the `y_*` rows, and it is infinite for a binomial or poisson model. With
a single fit (`m = 1`, as under IPW) the test is the ordinary one, with
`riv = fmi = 0`. **These p-values test one path at a time.** A small
`p_value` on `a` and on `b` is not a test of mediation: $`ab`$ is
nonlinear and its null is non-regular, which is the reason
[`infer()`](https://data-wise.github.io/missingmed/reference/infer.md)
exists (Section 4).

The pooled `MediationData` is built by **copy-modifying** a
per-imputation one (S7 is copy-on-write), replacing only
`@estimates =`$`\bar Q`$ and `@vcov =`$`T`$ — so all medfit metadata
(roles, predictors, families) is inherited and the aliases stay
name-addressable for
[`ci_mediation_data()`](https://data-wise.github.io/rmediation/reference/ci_mediation_data.html).

``` r

fit <- run(md_mi)            # m named MediationData
res <- pool(fit)             # pooled named MediationData + within/between/total vcov
res@tidy_table               # + statistic, df, riv, fmi, p_value (per path)
```

------------------------------------------------------------------------

## 4. MBCO under MI: D4-stacking (and why it is hosted here)

### 4.1 Why MBCO does not commute with Rubin’s rules

MBCO tests $`H_0: a b = 0`$. Since $`a b = 0 \iff a = 0 \lor b = 0`$,
the constrained log-likelihood is the **branch union**:

``` math
T = 2\big[\ell_{\text{full}} - \max(\ell_{a=0},\ \ell_{b=0})\big].
```

That [`max()`](https://rdrr.io/r/base/Extremes.html) is non-linear, so
the MBCO statistic of the *pooled* estimate is **not** the pool of
per-imputation MBCO statistics. You cannot pool first and test second —
you need the per-imputation fits.

### 4.2 D4 combination

Hence `MDMediationFit` retains the per-imputation list (exposed by
[`per_imputation_list()`](https://data-wise.github.io/missingmed/reference/per_imputation_list.md)),
and `infer(type = "mbco")` combines the per-imputation LRT statistics
with the **D4** rule (Chan & Meng 2022; Grund et al. 2021):

``` math
d_S = \tfrac{\text{LRT(stacked data)}}{K},\quad
r_4 = \max\!\Big(0, \tfrac{K+1}{k(K-1)}(\bar d - d_S)\Big),\quad
D_4 = \tfrac{d_S}{k(1+r_4)} \sim F_{k,\nu}.
```

#### Worked example: pooling three MBCO statistics

*Time: about 2 minutes.*

**After this you can** explain why averaging per-imputation test
statistics is anti-conservative, using a number.

**The punchline first.** The three statistics average to 7.5, which
looks significant. The correct pooled answer is **1.5**, which is not.
The gap between those two numbers is the missing information.

Take $`K = 3`$ imputations, one constraint ($`k = 1`$):

``` math
d_1 = 6.0,\quad d_2 = 7.5,\quad d_3 = 9.0
\;\Rightarrow\; \bar d = \mathbf{7.5};
\qquad d_S = \mathbf{6.0}
```

**Step 1 – measure the gap between the average and the stacked
statistic.** $`\bar d - d_S = 7.5 - 6.0 = 1.5`$

**Step 2 – scale it into $`r_4`$.**
$`r_4 = \max\!\big(0,\ \tfrac{K+1}{k(K-1)} \times 1.5\big)
= \tfrac42 \times 1.5 = \mathbf{3.0}`$

**Step 3 – deflate.**
$`D_4 = \tfrac{d_S}{k(1+r_4)} = \tfrac{6.0}{1 \times 4} = \mathbf{1.5}`$

**Step 4 – find the reference distribution.** Here $`k(K-1) = 2`$, which
is not $`> 4`$, so the small-sample branch applies:
$`\nu = \tfrac12 \cdot 2 \cdot (1 + \tfrac11)(1 + \tfrac13)^2 = 2(4/3)^2
= \mathbf{3.556}`$, giving
$`p = \Pr[F_{1,\,3.556} > 1.5] = \mathbf{0.296}`$.

![Three bars: naive mean of the per-imputation statistics 7.5, stacked
statistic 6.0, and the correct D4 value
1.5.](technical_files/figure-html/d4-deflation-1.png)

**Explain this one to yourself.** Why is $`\bar d`$*larger* than $`d_S`$
when both describe the same hypothesis?

Answer

Each per-imputation statistic is computed as though its filled-in
dataset were real, complete data – so each one ignores the uncertainty
that produced the filling-in, and is optimistic. Stacking averages the
log-likelihoods first, which partly cancels that optimism. The
systematic excess of $`\bar d`$ over $`d_S`$ is therefore an estimate of
how much of the evidence was manufactured by the imputation model rather
than observed. $`r_4`$ converts that excess into a deflation factor.

> **Watch the truncation.** If $`r_4`$ hits the $`\max(0, \cdot)`$
> floor, the correction vanishes and $`D_4 = d_S/k`$. Check `r4` in the
> returned object before trusting a borderline $`p`$.

**You can now** say why `MDMediationFit` must retain the per-imputation
list: $`\bar d`$ cannot be recovered from the pooled result alone.

### 4.3 Hosting decision

[`RMediation::mbco()`](https://data-wise.github.io/rmediation/reference/mbco.html)
is OpenMx-only with no MI entry point, so the D4 machinery is **hosted
in missingmed** (`R/mbco_mi.R`), ported from the Missing-Effect research
prototype. It reproduces the prototype **exactly** (max abs diff
$`\approx 5\times10^{-11}`$ across design cells). When `RMediation`
gains an MI entry point, this code should move upstream (`TODO` noted in
source).

------------------------------------------------------------------------

## 5. The IPW estimator

IPW is a robustness complement to MI (manuscript appendix): instead of
imputing, it **reweights the observed complete cases** to represent the
full sample under MAR. The whole estimator is a single internal branch,
`.ipw_run()`;
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md) and
`infer(type = "mc")` are unchanged.

### 5.1 Pipeline

``` r

md <- set_md_mediation(df, Y ~ X + M + C, M ~ X + C, treatment = "X",
  mediator = "M", method = "ipw",
  weight_formula = NULL, weight_stabilize = TRUE, weight_trim = 0.99,
  se_type = "sandwich")
res <- pool(run(md))         # MDMediationFit(m = 1) -> MDMediationResult (B = 0)
infer(res, type = "mc")
```

Because there is a single weighted fit, `MDMediationFit@m = 1` and
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
reduces to $`\bar Q = Q_1,\ B = 0,\ T = \bar U`$ — the result is
structurally identical to an MI result, so nothing downstream changes.

### 5.2 Weight estimation

Let $`R = 1`$ mark a complete case over the model variables.

- **Joint complete-case model (default).** `weight_formula = NULL` fits
  $`\text{logit }P(R=1\mid Z)`$ on the **fully observed** model
  variables (the MAR drivers); a single `formula` overrides the
  predictors.
- **Per-variable / sequential factorization.** A *named list* of
  formulas fits one model per incomplete variable and multiplies:
  $`P(\text{complete}) = \prod_V P(R_V = 1\mid \cdot)`$, following the
  causal order $`X \to M \to Y`$.

**Stabilized weights** (`weight_stabilize = TRUE`, default) use a
treatment-only numerator to reduce variance:
``` math
w_i = \frac{\hat P(R=1\mid X_i)}{\hat P(R=1\mid Z_i)} .
```

#### Worked example: four weights, stabilized and trimmed

*Time: about 2 minutes.*

**After this you can** predict what stabilization does to a point
estimate (nothing) and what trimming does to it (moves it).

**The punchline first.** Stabilization rescales every weight by the same
factor, so it **cannot move the point estimate**. Trimming *does* move
it – and it moves it by cutting exactly the case that needed the most
correction.

Four complete cases, denominator model $`\hat P(R=1\mid Z_i)`$, constant
numerator $`\hat P(R=1\mid X_i) = 0.5`$:

| $`i`$ | $`\hat P(R=1\mid Z_i)`$ | unstabilized $`1/\hat P`$ | stabilized $`0.5/\hat P`$ |
|----|----|----|----|
| 1 | 0.80 | 1.250 | **0.625** |
| 2 | 0.50 | 2.000 | **1.000** |
| 3 | 0.40 | 2.500 | **1.250** |
| 4 | 0.25 | 4.000 | **2.000** |
|  | mean | 2.4375 | **1.21875** |

**Read one:** case 1 had an 80% chance of being complete, so it stands
in for $`1/0.8 = 1.25`$ people. Case 4 had only a 25% chance, so it
stands in for $`1/0.25 = 4`$ – it is carrying three absent people on its
back.

**Two things to notice.**

1.  Every stabilized weight is exactly $`0.5\times`$ its unstabilized
    counterpart. A weighted regression is invariant to a common
    rescaling of the weights, so **the point estimate is identical
    either way**; stabilization buys variance, never consistency.
2.  `weight_trim = 0.75` caps at the 0.75 quantile of the stabilized
    weights, $`1.25 + 0.25(2.00-1.25) = \mathbf{1.4375}`$, pulling case
    4 from 2.000 down to 1.4375.

![Paired bars for four cases showing stabilized weights and the same
weights after trimming; only case 4, with the lowest completeness
probability, is cut.](technical_files/figure-html/ipw-weights-1.png)

**Explain this one to yourself.** Point 1 says a common rescaling is
harmless. Why, then, is trimming *not* harmless?

Answer

Rescaling multiplies every weight by the same constant, so the
*relative* contributions – which is all a weighted fit sees – are
unchanged. Trimming changes only the largest weights, so it changes the
relative contributions. And it always cuts the cases with the smallest
$`\hat P(R=1\mid Z)`$: exactly the under-represented ones the weighting
existed to recover. **Trimming changes the estimand; it does not merely
stabilize the estimate.**

**You can now** explain the bias-variance trade in `weight_trim` without
reaching for a simulation.

**Trimming** (`weight_trim`) caps weights at an upper quantile of the
untrimmed complete-case weights; `1` disables it.

### 5.3 Variance: sandwich vs model

IPW’s weighted-GLM model-based vcov is optimistic (it ignores that
weights were estimated). `se_type = "sandwich"` (the IPW default) uses
heteroskedasticity-consistent
[`sandwich::vcovHC`](https://zeileis.codeberg.page/sandwich/reference/vcovHC.html)
instead. This is implemented **in medfit** via an injectable `vcov_fun`
threaded through `extract_mediation()` (so the named-vcov assembly stays
in one place); missingmed just passes `se_type` through.

> MBCO for IPW is **not** implemented (a weighted LRT is
> methodologically distinct); `infer(type = "mbco")` on an IPW fit
> errors with guidance.

------------------------------------------------------------------------

## 5A. Non-gaussian models (`family_y`, `family_m`) and the scale of `a*b`

[`set_md_mediation()`](https://data-wise.github.io/missingmed/reference/set_md_mediation.md)
takes `engine`, `family_y` and `family_m` and forwards them to
[`medfit::fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.html),
whose default engine already **is** `"glm"`. Both estimators and both
inference types therefore accept non-gaussian families with no extra
machinery: a binary mediator (`family_m = binomial()`), a binary outcome
(`family_y = binomial()`) and a count outcome (`family_y = poisson()`)
all run through `set_md_mediation() -> run() -> pool() -> infer()`.

### 5A.1 The scale caveat

For a non-identity link, `a` and `b` are **link-scale** coefficients, so
their product – and the Monte-Carlo interval around it – is on the link
scale too:

| Model | `a` | `b` | `a*b` is… |
|----|----|----|----|
| gaussian / gaussian | mean difference | mean difference | a mean difference |
| binomial mediator | log-odds | mean difference | change in Y per log-odds of M |
| binomial outcome | mean difference | log-odds | log-odds units |
| poisson outcome | mean difference | log-rate | log-rate units |

Two consequences worth stating plainly:

1.  `a*b` under a non-identity link is **not** a risk difference, a risk
    ratio or an odds ratio, and `exp(a*b)` does not produce one.
    Reporting it as such is a category error, not a rounding issue.
2.  Rubin’s rules are applied to the **coefficients**, which is
    standard. Pooling a transformed quantity (an odds ratio, say) is a
    different and much less well-behaved operation;
    [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
    deliberately does not do it.

Where a response-scale contrast is wanted – a natural direct/indirect
effect on the risk difference or risk-ratio scale – the mediation
formula must be applied to the fitted models, which is outside
missingmed’s orchestration remit. That is a fitting-layer concern
(medfit), not a pooling one.

### 5A.2 IPW plus a binomial family: the non-integer-successes warning

[`stats::glm()`](https://rdrr.io/r/stats/glm.html) emits
`non-integer #successes in a binomial glm!` whenever a binomial fit
receives non-integer prior weights. IPW weights are inverse sampling
probabilities, not trial counts, so the warning fires on every
`method = "ipw"` fit with a binomial family. It is a false alarm: the
weighted score equations being solved are exactly the ones IPW
specifies, and the point estimates and sandwich SEs are unaffected. It
is left unsuppressed rather than silenced, so that a genuine
non-integer-response mistake still surfaces.

------------------------------------------------------------------------

## 5B. MNAR sensitivity (`sensitivity_mnar()`)

The pipeline estimates under **MAR** — `mice` imputes under MAR by
construction. MAR versus MNAR is not testable from the observed data, so
there is nothing to estimate without an assumption imported from outside
it.
[`sensitivity_mnar()`](https://data-wise.github.io/missingmed/reference/sensitivity_mnar.md)
therefore produces a **curve**, not an estimate:

> if the unobserved values of the target sit `delta` units away from
> what MAR imputation implies, the indirect effect is *X*.

No rung is “the MNAR estimate”. Each is conditional on its own delta.

### 5B.1 Method

Delta-adjusted imputation in the pattern-mixture sense (van Buuren,
*FIMD* §9.2; Leacy et al. 2017). Per rung: re-impute with the shift
applied, then run the existing pipeline unchanged.

For a **continuous** target the canonical procedure imputes under MAR
and then adds the constant to the imputed values (Hayati Rezvan et
al. 2018). For a **binary** target an additive shift on a drawn 0 or 1
is meaningless; the shift belongs on the imputation model’s linear
predictor instead. Which construction runs depends on the target’s
imputation method:

| Baseline method | Mechanism (`@mechanism_used`) | Delta scale |
|----|----|----|
| `norm`, with a `ums` string | `mnar.norm` — `mice`’s NARFCS method, via `blots` | raw units of the target |
| `logreg` (binary) | `mnar.logreg`, via `blots` | **log-odds** |
| `norm` with a numeric `delta`; `pmm`, `norm.nob`, `norm.boot`, `cart`, … | `post` — shift the drawn values | raw units of the target |
| `logreg.boot`, `polyreg`, `polr`, `lda` | refused | — |

NARFCS is Tompsett et al. (2018); the `mice` methods are
Moreno-Betancur, van Buuren & White (2020). For a constant delta on a
`norm` target the first and third rows would give **identical draws** —
the offset is a scalar added to a normal draw’s linear predictor, which
is arithmetically the same as adding it to the draw — so a numeric
`delta` stays on `post`, and `mnar.norm` is used only where it adds
something: a covariate-varying `ums`. Only an *exact* method match is
delegated: swapping `norm.boot` for `mnar.norm`, say, would change the
imputation method itself, and `delta = 0` would stop reproducing the MAR
analysis. [`print()`](https://rdrr.io/r/base/print.html) and
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) state the
mechanism and scale that ran.

A delegated target also accepts a **covariate-varying** delta through
`ums`, passed verbatim to NARFCS: `ums = c("0", "1 + 0.5*C")` offsets
each row by $`1 + 0.5\,C`$. A string grid has no numeric ordering, so
[`summary()`](https://rdrr.io/r/base/summary.html) does not compute a
tipping point for it.

Re-imputation rebuilds from the `mids` object’s **stored settings**,
never from its recorded `call` — a `mids` built inside a function stores
a call referencing that function’s local variables, which does not
resolve anywhere else.

``` r

sens <- sensitivity_mnar(md, delta = c(0, -0.5, -1, -1.5, -2))
tidy(sens)
summary(sens)   # adds the tipping point, if the grid contains one
```

### 5B.2 What `delta` actually is — read before choosing a value

`delta` is a **conditional** sensitivity parameter (CSP): a difference
conditional on all remaining variables *and their missingness
indicators*. The quantity an analyst can actually reason about —
“non-respondents average half a point lower” — is a **marginal** one
(MSP). They are different numbers.

Supplying an elicited MSP where a CSP is expected is the standard
failure mode of this method. Tompsett et al. (2018) measure it: coverage
fell from 95% to **49.3%** when an elicited MSP was inserted directly as
the CSP.

`missingmed` cannot make the specified parameter marginal, but it can
show you the realized one. Every rung reports `msp`. The run below uses
a data set where `M` and `Y` are both incomplete and `M`’s missingness
depends on `X`:

``` r

library(missingmed)
set.seed(9)
n <- 400
C <- rnorm(n)
X <- rbinom(n, 1, 0.5)
M <- 0.5 * X + 0.4 * C + rnorm(n)
Y <- 0.45 * M + 0.2 * X + 0.3 * C + rnorm(n)
d <- data.frame(X, M, Y, C)
d$M[runif(n) < plogis(-1.6 + 1.6 * X + 0.4 * C)] <- NA
d$Y[runif(n) < plogis(-1.8 + 0.5 * X + 0.5 * C)] <- NA
meth <- mice::make.method(d)
meth["M"] <- "norm"
imp <- mice::mice(d, m = 5, maxit = 5, method = meth, seed = 9, printFlag = FALSE)
md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)
grid <- c(0, -0.5, -1, -1.5, -2)
sens_tab <- tidy(sensitivity_mnar(md, delta = grid, n.mc = 1e4, seed = 9))
knitr::kable(
  data.frame(`delta (CSP)` = grid, `msp (realized)` = round(sens_tab$msp, 3),
    estimate = round(sens_tab$estimate, 3), check.names = FALSE)
)
```

| delta (CSP) | msp (realized) | estimate |
|------------:|---------------:|---------:|
|         0.0 |          0.237 |    0.269 |
|        -0.5 |         -0.310 |    0.182 |
|        -1.0 |         -0.813 |    0.105 |
|        -1.5 |         -1.318 |    0.037 |
|        -2.0 |         -1.829 |   -0.010 |

Two things to read off that table. First, `msp` is **non-zero at delta =
0** (here 0.237): under MAR, imputed values legitimately differ from
observed ones when missingness depends on covariates. Second, `msp` is
not simply `delta` shifted: its increments differ from the grid’s by up
to 0.047, a chained-equations effect. With a single incomplete variable
the increments coincide exactly; with more, part of the shift circulates
back through the other imputation models.

### 5B.3 Reading a tipping point

[`summary()`](https://rdrr.io/r/base/summary.html) reports the delta at
which the interval first includes zero. Judge plausibility on the
**realized `msp`**, not on the CSP: Tompsett et al. note a CSP-scale
tipping point has no direct clinical interpretation. Resseguier et al.
add the constraint that a tipping value must “correspond to reasonable
hypotheses supported by epidemiologic evidences” — a tipping point that
requires an implausible departure from MAR is *reassurance*, not a
warning.

The figure below plots the run from 5B.2. It shows why the resolution
warning matters: the interval’s lower bound crosses zero near **-1.12**,
but the grid `c(0, -0.5, -1, -1.5, -2)` can only *report* **-1.5**.

![Sensitivity curve of the indirect effect against delta with its
confidence band, from the run in section 5B.2; the reported tipping
point on the grid is marked alongside the interpolated crossing between
two grid points.](technical_files/figure-html/sensitivity-curve-1.png)

### 5B.4 Binary targets: when is a log-odds delta of 1 plausible?

On the `mnar.logreg` route `delta` is a **conditional log-odds**
difference: at `delta = 1` the odds that a non-respondent’s value is 1
are $`e \approx 2.72`$ times what MAR imputation implies, *given every
other variable*. The CSP/MSP caution of 5B.2 applies with an extra twist
— the two sit on **different scales**. `delta` is log-odds; the reported
`msp` is a prevalence difference on the probability scale.

The same log-odds step moves prevalence by different amounts depending
on where it starts. The chunk below imputes a binary mediator with
`mnar.logreg` at three log-odds deltas and reports the mean imputed
prevalence (it runs when the vignette is built, so the numbers always
come from the code shown):

``` r

set.seed(7)
n <- 600
C <- rnorm(n)
X <- rbinom(n, 1, 0.5)
M <- rbinom(n, 1, plogis(-0.3 + 0.8 * X + 0.3 * C))
Y <- 0.5 * M + 0.2 * X + 0.3 * C + rnorm(n)
d <- data.frame(X, M, Y, C)
d$M[runif(n) < 0.35] <- NA # missing completely at random
meth <- mice::make.method(d)
meth["M"] <- "mnar.logreg"
prev <- vapply(c(0, 1, 2), function(delta) {
  imp <- suppressWarnings(mice::mice(d,
    m = 5, maxit = 5, method = meth, seed = 7, printFlag = FALSE,
    blots = list(M = list(ums = as.character(delta)))
  ))
  mean(unlist(imp$imp$M))
}, numeric(1))
knitr::kable(
  data.frame(`log-odds delta` = c("0 (MAR)", "1", "2"),
    `imputed prevalence` = round(prev, 3), check.names = FALSE)
)
```

| log-odds delta | imputed prevalence |
|:---------------|-------------------:|
| 0 (MAR)        |              0.438 |
| 1              |              0.683 |
| 2              |              0.845 |

The first step added 24.5 points, the second 16.2 — the logistic curve
flattens toward 1. So:

- **A delta of 1 is plausible** when external evidence — a follow-up of
  non-respondents, a validation subsample, a substantive account of
  *why* people with the outcome stop responding — supports a conditional
  odds ratio of roughly 2.7 among the missing. Judge that against the
  realized `msp`, not against the delta.
- **It is not plausible by default.** An odds ratio of 2.7 is a large
  conditional effect. When the MAR prevalence is already near 0 or 1,
  even a modest delta pushes the imputed values toward all-0 or all-1,
  and the curve mostly reflects that the grid ran out of room.
- **`delta = 0` still reproduces the MAR analysis exactly**, so the
  curve is anchored at the analysis you would otherwise report.

### 5B.5 Limitations

| Limitation | Status |
|----|----|
| `method = "ipw"` | Errors. IPW has no imputations to shift; a weighting analogue is a different method with a different parameter. |
| Binary 0/1 targets whose imputations are 0/1 | Errors (`pmm`, `cart`, `sample`, …): an added delta turns 0/1 into 1/2. Re-impute with `logreg`. A normal-model (`norm*`) imputation is continuous and is allowed; keep its raw-scale delta small and check `msp`. |
| Categorical targets | Binary via `logreg` only (§5B.1). `polyreg`/`polr`/`lda` error — `mice` has no NARFCS method for them — and so does `logreg.boot`. A binary *factor* mediator is not yet supported by the mediation fit itself. |
| `pmm` targets | Allowed, with a message: shifted values may leave the observed range `pmm` otherwise guarantees. |
| Imputation-model compatibility | **Assumed, not checked.** The `mids` arrives pre-built; if its imputation model is incompatible with the mediation model, the curve confounds departure-from-MAR with misspecification. `smcfcs` is the upstream fix. |
| CSP calibration | Not implemented. Searching for the CSP that realizes a target MSP (Tompsett et al. §8) is the principled fix for §5B.2; v2. |

------------------------------------------------------------------------

## 6. Cross-package engineering decisions

These changes were made upstream to satisfy missingmed’s contracts; each
is the “small upstream fix” that a new capability turned out to need.

| Decision | Where | Why |
|----|----|----|
| `fit_mediation(weights=)` via `do.call` (value inlined), added only when non-NULL | medfit | `glm` evaluates `weights` by NSE in the **formula’s** environment; passing it through `...` resolves to [`stats::weights`](https://rdrr.io/r/stats/weights.html) (a function). `do.call` inlines the vector; gating on non-NULL keeps the unweighted path byte-identical. |
| `se_type` -\> injectable `vcov_fun` in `extract_mediation` | medfit | Keeps named-vcov assembly in one place; [`sandwich::vcovHC`](https://zeileis.codeberg.page/sandwich/reference/vcovHC.html) swaps in for [`stats::vcov`](https://rdrr.io/r/stats/vcov.html) without missingmed re-implementing medfit’s alias expansion. |
| Tidiers exported with `@exportS3Method broom::tidy` | missingmed | Plain `@export` registers `S3method(tidy, *)` against the wrong generic; the package-qualified form binds to broom’s generic so [`tidy()`](https://generics.r-lib.org/reference/tidy.html)/[`broom::tidy()`](https://generics.r-lib.org/reference/tidy.html) dispatch. |
| [`S7::S4_register()`](https://rconsortium.github.io/S7/reference/S4_register.html) per S7 class | missingmed | The legacy S4 generics (`print`/`summary`) require S7 classes to be S4-registered before S7 methods can attach. |
| `namespace` roclet enabled | missingmed | Lets roxygen regenerate NAMESPACE for the many new S7 exports (surfaced + fixed a latent `generics`/`broom` `tidy` import clash). |
| Pooled `MediationData` via copy-modify | missingmed | Inherits all medfit metadata; only estimates/vcov/paths change, so names stay intact for RMediation. |

------------------------------------------------------------------------

## 7. Design-choice summary

- **S7-first**, three classes mirroring the S4 ancestors; estimator and
  model as orthogonal axes.
- **Delegate fitting to medfit** (`fit_mediation`) rather than
  re-implement GLM mediation — keeps missingmed thin and the
  `MediationData` naming canonical.
- **Names are the API**: pooled estimates/vcov stay named so RMediation
  resolves paths by label.
- **MBCO hosted locally** until RMediation offers an MI entry point;
  exact parity with the research prototype is the acceptance bar.
- **IPW = thin
  [`run()`](https://data-wise.github.io/missingmed/reference/run.md)
  branch + passthrough
  [`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)**;
  weights support both joint and sequential models, stabilized and
  trimmed; sandwich SE by default.
- **S4 deprecated** with
  [`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html) shims for
  one cycle.

------------------------------------------------------------------------

## 7A. Self-check

*Four questions, about 10 minutes. Attempt each before opening its
answer – retrieval is what makes it stick.*

**1. Procedural** *(1 min, arithmetic)* With $`m = 5`$,
$`\bar U = 0.04`$ and $`B = 0.02`$, compute $`T`$ and the fraction of
missing information.

Answer

$`T = \bar U + (1+\tfrac15)B = 0.04 + 1.2(0.02) = 0.04 + 0.024 =
\mathbf{0.064}`$.

$`\gamma = 0.024/0.064 = \mathbf{0.375}`$ – 37.5% of the information
about this parameter is missing.

*Stuck?* Re-read the worked example in section 3, steps 2 and 4.

**2. Conceptual** *(2 min)* Section 4.1 shows
$`T = 2[\ell_{\text{full}} - \max(\ell_{a=0},
\ell_{b=0})]`$. Why does the
[`max()`](https://rdrr.io/r/base/Extremes.html) – rather than the
product $`ab`$ itself – prevent pooling before testing?

Answer

Rubin’s rules are a **linear** operation: $`\bar Q`$ and $`T`$ are
averages of per-imputation quantities.
[`max()`](https://rdrr.io/r/base/Extremes.html) is not linear, so the
$`\max`$ of the pooled log-likelihoods is not the pool of the
per-imputation $`\max`$es – the constrained fit may select the $`a=0`$
branch in one imputation and the $`b=0`$ branch in another. That is why
`MDMediationFit` retains the per-imputation list.

The sharpest part: the product $`ab`$ is *also* nonlinear, yet it causes
no such problem, because
[`pool()`](https://data-wise.github.io/missingmed/reference/pool.md)
pools $`(a,b)`$ linearly and defers the product to `RMediation`. **A
deferral is available for a product; none is available for a branch
selection.**

*Stuck?* Sections 4.1 and 4.2.

**3. Critical** *(3 min)* A colleague reports
`sensitivity_mnar(delta = c(0, -1, -2))` with a tipping point at
$`\delta = -2`$, and concludes: *“the mediation effect is robust unless
non-respondents score 2 points lower.”* Name two things wrong with that
sentence.

Answer

1.  **Wrong parameter.** $`\delta`$ is *conditional*; “non-respondents
    score 2 points lower” is a *marginal* claim. The realized `msp` at
    $`\delta = -2`$ will not be $`-2`$ – read it off the output instead
    of assuming it (section 5B.2). Tompsett et al. (2018) measured the
    cost of this exact confusion: coverage fell from 95% to 49.3%.
2.  **Wrong resolution.** Three grid points locate a tipping point no
    better than the grid spacing. The true crossing lies somewhere in
    $`(-1, -2]`$.

A third, if you want it: *“robust”* is a claim about **plausibility**,
and nothing in the output speaks to whether $`\delta = -2`$ is plausible
for this study. The package can tell you where the conclusion flips;
only you can say whether that is a lot.

*Stuck?* Sections 5B.2 and 5B.3.

**4. Transfer** *(4 min)* You have a binary 0/1 mediator with 30%
missingness, imputed with `mice`’s default for a numeric column.
`sensitivity_mnar(md, delta = 1)` stops with an error saying the target
is binary. Why does the package refuse, and what do you change?

Answer

**Why it refuses.** `mice` imputes a *numeric* 0/1 column with `pmm`,
not `logreg`, so the routing table in 5B.1 sends it down the `post`
route: the delta would be **added to the drawn values**, and a drawn 0
or 1 would become 1 or 2. Under a gaussian mediator model that runs
without complaint and analyzes a variable that no longer means anything;
under a binomial one it fails late, inside `glm`. The package refuses
any 0/1 target whose *imputations* are 0/1 (as `pmm`’s are) rather than
let either happen. A normal-model (`norm*`) imputation would be allowed,
because its values are already continuous.

**The change.** Re-impute with `method["M"] <- "logreg"`. The target
then routes to `mnar.logreg`, which shifts the imputation model’s
**linear predictor**, puts $`\delta`$ on the log-odds scale, and keeps
every imputed value 0 or 1. Check the printed `delta applied by:` line:
it should read `mnar.logreg (log-odds)`.

*Stuck?* Section 5B.1’s routing table.

### 7A.1 Three common confusions

**“`delta = 0` should give `msp = 0`.”** No. Under MAR, imputed values
legitimately differ from observed ones whenever missingness depends on
covariates, because the imputed subgroup has a different covariate mix.
What $`\delta = 0`$ guarantees is that the *analysis* reproduces the MAR
result exactly – not that the marginal shift is zero. The table in
section 5B.2 shows `msp = 0.244` at `delta = 0`.

**“`se_type = "sandwich"` corrects for having estimated the weights.”**
No. The sandwich is heteroskedasticity-consistent and treats $`\hat\pi`$
as fixed. Robins, Rotnitzky and Zhao (1994) show that ignoring weight
estimation makes the variance **conservative** – estimating the weights
*reduces* variance relative to knowing them. The intervals are honest,
just wider than necessary.

**“IPW and MI should agree; if they disagree, one is broken.”** No. They
target the same estimand under MAR but use different information: MI
uses partially observed rows, IPW discards them and reweights what
remains. Disagreement beyond Monte-Carlo noise is **diagnostic** –
usually of a weight model missing a MAR driver, or an imputation model
incompatible with the substantive model – not of a bug.

------------------------------------------------------------------------

## 8. References

- Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in Surveys*.
  Wiley.
- Chan, K. W., & Meng, X.-L. (2022). Multiple improvements of multiple
  imputation likelihood ratio tests. *Statistica Sinica*.
- Grund, S., Lüdtke, O., & Robitzsch, A. (2021). Pooling methods for
  likelihood-ratio tests with multiply imputed data. *Psychological
  Methods*.
- Seaman, S. R., & White, I. R. (2013). Review of inverse probability
  weighting for dealing with missing data. *Statistical Methods in
  Medical Research*.
- van Buuren, S. *Flexible Imputation of Missing Data*, 2nd ed., §9.2
  (delta adjustment).
- Leacy, F. P., Floyd, S., Yates, T. A., & White, I. R. (2017). Analyses
  of sensitivity to the missing-at-random assumption using multiple
  imputation with delta adjustment. *American Journal of Epidemiology*,
  185(4), 304-315.
- Tompsett, D. M., Leacy, F., Moreno-Betancur, M., Heron, J., &
  White, I. R. (2018). On the use of the not-at-random fully conditional
  specification (NARFCS) procedure in practice. *Statistics in
  Medicine*, 37(15), 2338-2353.
- Hayati Rezvan, P., Lee, K. J., & Simpson, J. A. (2018). Sensitivity
  analysis within the multiple imputation framework using
  delta-adjustment. *Longitudinal and Life Course Studies*, 9(3),
  259-278.
- Resseguier, N., Giorgi, R., & Paoletti, X. (2011). Sensitivity
  analysis when data are missing not-at-random. *Epidemiology*, 22(2),
  282-287.
