# PLAN — the remaining parked review findings (2026-08-30)

Source: the parked section of `PLAN-pre-v0.3.0-review-fixes-2026-08-29.md`, after
`SPEC-mbco-constrained-models-2026-08-30.md` closed the substantive one.

Every defect below was **reproduced before being planned**; the numbers are measured,
not quoted from the review.

**Branch:** work on `dev` (all changes are to existing files). One commit per item.

**Estimate:** ~70 min total.

---

## Item 1 — `infer()` ignores `@conf_level` (~15 min)

**Status: CONFIRMED, measured.**

`R/infer.R:27,49` hard-code `level = 0.95`. The property is validated in
`set_md_mediation()`, propagated correctly through `run()` (`R/run.R:49`) and
`pool()` (`R/pool.R:97`) — and then never read.

Measured (n = 300, m = 3, `conf_level = 0.90`, n.mc = 50000, same seed):

```
@conf_level on the object   0.90
infer(res)                  CI width 0.3294   <- what the user gets
infer(res, level = 0.90)    CI width 0.2752   <- what they asked for
                            19.7% wider than requested, silently
```

The user set the level once, at the top of the pipeline, exactly where the API invites
them to. Nothing warns.

**Fix.** Default `level = NULL` in both `infer()` methods and in
`sensitivity_mnar()` (`R/sensitivity_mnar.R:53`, same hard-coded default); resolve as
`level <- level %||% object@conf_level`. An explicit `level =` still wins, so no
existing call changes behavior.

**Why NULL rather than reading the slot directly:** the caller must retain the ability
to override per call. `level = NULL` distinguishes "not specified" from "specified as
0.95", which a bare default cannot.

**Tests.** `conf_level = 0.90` then `infer()` gives the same width as
`infer(level = 0.90)`; an explicit `level =` overrides the slot; the default path
(`conf_level` untouched) is unchanged at 0.95.

---

## Item 2 — the pooled object carries imputation 1's nuisance parameters (~25 min)

**Status: CONFIRMED, measured.**

`R/pool.R:69` builds the pooled `MediationData` by copy-modifying
`object@per_imputation[[1]]`, then overwrites only `@estimates`, `@vcov`, `@a_path`,
`@b_path`, `@c_prime`. Everything else is **imputation 1's**, presented as pooled:

```
pooled@sigma_m   1.001004   (imp 1: 1.001004,  imp 2: 1.022008)
pooled@data      identical to imputation 1's completed frame
```

`@sigma_m`, `@sigma_y`, `@converged` and `@n_obs` are in the same position.

**This is a labelling defect, not a numerical one for the CI path.** `ci_mediation_data()`
reads `@estimates` and `@vcov`, both correctly pooled. The risk is a user reading
`pooled@sigma_m` and believing it is a pooled residual SD.

**Fix.** Two parts, and the second is the one that matters:

1. Pool what is poolable: `@sigma_m`, `@sigma_y` as the average across imputations —
   **flagged**, see the open question below.
2. Blank what is not: set `@data` to a zero-row frame with the same columns (or
   whatever `medfit::MediationData`'s validator permits), and `@converged` to
   `all(...)` across imputations. A pooled object has no single completed dataset, and
   silently carrying one is worse than carrying none.

**OPEN QUESTION for the author — do not implement part 1 blind.** Averaging
\(\hat\sigma\) across imputations is not the same as pooling \(\hat\sigma^2\), and
neither is the MI estimate of the residual SD in the Rubin sense. Options: (a) average
\(\hat\sigma^2\) then square-root, (b) average \(\hat\sigma\), (c) set both to
`NA_real_` and document that the pooled object does not carry nuisance parameters.
**Recommendation: (c).** The package's stated job is the mediation paths; inventing a
pooled residual SD nobody asked for is scope the spec never claimed, and `NA` cannot be
misread the way imputation 1's value can. Cheap to revisit.

**Blocked on that answer for part 1.** Part 2 proceeds regardless.

---

## Item 3 — no `p_value` / df / fmi in the pooled tidy table (~20 min)

**Status: CONFIRMED.**

```
tidy columns: term, estimate, std_error, var_w, var_b, var_tot
has p_value?  FALSE
```

`R/MDMediationResult.R:11-12` documents a `p_value` column, and the legacy S4
`pool_sem()` returned one. The column is simply absent — the docs describe a table the
code does not build.

**Fix.** Add per-term Rubin degrees of freedom and the derived quantities via
`mice::pool.scalar(Q, U, n)`, which returns `df`, `r` (RIV) and `fmi` and is already a
hard dependency. Add `df`, `fmi`, `statistic` and `p_value` columns.

**Caveat to carry into the docs:** these are **per-path** (a, b, c') Wald quantities.
They are *not* a test of the indirect effect — `a*b` is nonlinear and its null is
non-regular (that is the entire reason MBCO and the MC CI exist). A `p_value` column
sitting next to an `a` row invites exactly the wrong reading, so the roxygen must say so
in the same breath, and the vignette's section 3 should note it.

**Alternative considered and rejected:** drop the `p_value` mention from the docs
instead. Rejected because the columns are genuinely useful for the individual paths and
the legacy API provided them; removing the promise is a regression in capability, not a
fix.

---

## Item 4 — tipping point uses grid order, not |delta| (~10 min)

**Status: CONFIRMED by reading; not yet measured.**

`R/methods-output.R:91` takes `which(!excl)[1L]` — the first rung *in the order the user
supplied*. With `delta = c(-2, 0, -1)` the reported tipping point is whichever of those
happens to come first, not the smallest departure from MAR. It also never fires for
`type = "mbco"`, whose rungs carry no `conf_low`/`conf_high`.

**Fix.** Sort candidate rungs by `abs(delta)` before taking the first, and use a
type-agnostic "null retained?" predicate so `mbco` rungs participate. Guard the
`delta = 0` rung: an interval covering zero at `delta = 0` is not a tipping point, it is
a null result at MAR.

**Note:** the vignette's new sensitivity-curve figure already teaches that a grid can
only report a tipping point it landed on. This fix makes the reported value the *nearest*
such point, which is what that figure's annotation implies the software does.

---

## Item 5 — pkgdown deploys from `dev` (~5 min, needs a decision)

`.github/workflows/pkgdown.yaml:6` triggers on `push: [main, dev]` and deploys whenever
the event is not a pull request, so the public site can document unreleased API.

**This is a policy question, not a defect.** Deploying from `dev` is a legitimate choice
for a package whose users are tracking the r-universe build. **Recommendation: leave it,
and revisit only if the site and the released version actually diverge in a way that
misleads.** Right now they do not.

Not implementing without an explicit instruction.

---

## Gate (before commit)

- Full suite green; expect ≥ 168 + new tests.
- `R CMD check --as-cran` 0/0/0.
- No new exports, so `_pkgdown.yml`'s reference index is untouched.
- Each item's reproducer must fail on the pre-fix source.
