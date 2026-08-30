# SPEC: MBCO constrained models must null the whole path

| | |
|---|---|
| **Status** | draft — **§4 needs the author's ruling before implementation** |
| **Created** | 2026-08-30 |
| **Source** | adversarial `/code-review high main..dev`, finding 3; parked in `PLAN-pre-v0.3.0-review-fixes-2026-08-29.md` |
| **Affects** | `R/mbco_mi.R:17-18` (`.mm_ll_med`) |
| **Target** | v0.4.0 |
| **Severity** | correctness — silent, no error, no warning |

## 1. The defect

`.mm_ll_med()` builds the constrained models with

```r
fm_use <- stats::update(formula_m, paste0(". ~ . - ", treatment))   # a = 0
fy_use <- stats::update(formula_y, paste0(". ~ . - ", mediator))    # b = 0
```

`update()` removes only the **main-effect term whose label is exactly that
name**. Every other term carrying the variable survives. Verified against R
4.6.1:

| formula | `update(. ~ . - M)` | mediator still present? |
|---|---|---|
| `Y ~ X + M + C` | `Y ~ X + C` | no — correct |
| `Y ~ X * M + C` | `Y ~ X + C + X:M` | **yes**, via `X:M` |
| `Y ~ X * M * C` | `Y ~ X + C + X:M + X:C + M:C + X:M:C` | **yes**, three terms |
| `Y ~ poly(M, 2) + X` | `Y ~ poly(M, 2) + X` | **yes — unchanged** |

The a-path has the identical flaw: `M ~ X * C` minus `X` yields `M ~ C + X:C`.

So the "constrained" model is not constrained. \(\ell_C\) is larger than the
true constrained log-likelihood, and since \(T = 2(\ell_F - \ell_C)\), the
statistic is **systematically too small**.

## 2. Measured impact

n = 800, gaussian, true `X:M` interaction present, single dataset (medfit +
RMediation installed, R 4.6.1):

| outcome model | \(T\) now | \(T\) with the fix in §3 | |
|---|---|---|---|
| `Y ~ X + M + C` | 79.7323 | 79.7323 | unchanged — see §5 |
| `Y ~ X * M + C` | 78.4830 | 79.7323 | deflated |
| `Y ~ poly(M, 2) + X` | **0.0000** | 79.7323 | **test is inert** |
| `M ~ X * C` (a-path) | 79.4784 | 80.2884 | deflated |

**The `poly()` row is the severe one.** The constrained model equals the full
model exactly, so \(T = 0\), \(p = 1\), and the test can never reject — for any
data, at any sample size, with no diagnostic.

**Correcting the review's characterization.** The review called this
"anti-conservative". It is the opposite: \(\ell_C\) too large makes \(T\) too
small, so the test **loses power** and is conservative. Measured under a true
null (\(b = 0\)) the same deflation appeared (\(T\): 1.955 → 0.040). The bug is
still a bug — a test that cannot reject is worthless — but the direction matters
for how it is described in NEWS, and "anti-conservative" would have been wrong.

## 3. The mechanical fix (settled, not controversial)

Drop **every term whose variables include the target**, using `terms()` rather
than `update()`:

```r
.mm_drop_path <- function(formula, var) {
  tl <- attr(stats::terms(formula), "term.labels")
  keep <- tl[!vapply(tl, function(t) var %in% all.vars(str2lang(t)), logical(1))]
  stats::reformulate(if (length(keep)) keep else "1",
                     response = all.vars(formula)[1])
}
```

`all.vars(str2lang(t))` sees inside `poly(M, 2)`, `I(M^2)`, `log(M)`, `ns(M, 3)`
and `X:M` alike, so the rule needs no catalog of term shapes. Verified:

| formula | result |
|---|---|
| `Y ~ X * M + C` | `Y ~ X + C` |
| `Y ~ poly(M, 2) + X` | `Y ~ X` |
| `Y ~ X * M * C` | `Y ~ X + C + X:C` |
| `Y ~ log(M) + X` | `Y ~ X` |
| `M ~ X * C` (drop `X`) | `M ~ C` |

**Parity with the research prototype is preserved.** For `Y ~ X + M + C` /
`M ~ X + C` — the only shape the prototype handled — old and new agree to the
digit (79.7323 both). The `R/mbco_mi.R:3` parity claim therefore survives this
change and does not need re-derivation. This is the fact that makes the fix
safe to ship.

## 4. The part that is NOT settled — needs the author's ruling

§3 is mechanically correct for *nonlinear* mediator terms: `poly(M, 2)` is a
b-path, and nulling the b-path must remove it. There is no ambiguity.

**An `X:M` interaction is a different question, and it is a question about the
estimand, not about code.** With exposure-mediator interaction the indirect
effect is not \(ab\); in VanderWeele's decomposition the natural indirect effect
involves both the mediator main effect and the interaction. So "the b-path is
zero" admits more than one reading:

| reading | constrained outcome model | interpretation |
|---|---|---|
| **(i) M has no effect on Y at all** | drop `M` and `X:M` | "no mediation of any kind" — what §3 implements |
| **(ii) only the main effect is zero** | drop `M`, keep `X:M` | mediation operates purely through the interaction |
| **(iii) refuse** | — | the estimand is undefined for this model; error out |

MBCO as published (Tofighi & Kelley 2020, *Psychological Methods* 25(4):
496–515) is stated for the no-interaction case. **Whether MBCO's null extends to
(i) is a methodological question for the author, not an implementation detail,
and this spec does not decide it.**

**Recommendation, for the author to accept or overrule:** ship §3 for the
unambiguous nonlinear cases now, and take reading (iii) for `X:M` — error with
guidance — until (i) is confirmed. Rationale: (i) is almost certainly right, but
"almost certainly" is the wrong standard for silently redefining a published
test's null hypothesis. An error costs a user one message; a wrong null costs
them a wrong inference they cannot see.

If the author confirms (i), the error branch is deleted and §3 covers
everything — a one-line change.

## 5. Second finding, incidental but worth recording

When the `max()` in `.mm_mbco_T()` selects the **a-branch**, the outcome model
appears in both \(\ell_F\) and \(\ell_C\) and **cancels exactly**, so \(T\) does
not depend on the outcome model at all. That is why row 1 and row 2 of §2's
table share the value 79.7323 under the fix. This is correct behavior, not a
defect, but it is surprising enough to belong in a comment: a user changing the
outcome model and seeing \(T\) not move is looking at cancellation, not a bug.

## 6. Also in scope (same function, smaller)

`.mm_ll_med()` hard-codes `stats::glm()`. It ignores `@engine` and, for an IPW
fit, the weights. Today that is masked because `infer(type = "mbco")` errors on
IPW fits by design, and the MI path is glm-only — so it is latent, not live.
Fix it in the same pass or record it as a known limitation; do not leave it
undocumented.

## 7. Acceptance criteria

- [ ] `Y ~ X + M + C` / `M ~ X + C`: \(T\) unchanged to `1e-10` (parity gate).
- [ ] `Y ~ poly(M, 2) + X`: \(T > 0\) and matches the linear case's value on
      equivalent data — a regression test pinning that the test is no longer
      inert.
- [ ] `Y ~ log(M) + X`, `Y ~ I(M^2) + M + X`: mediator absent from the
      constrained model.
- [ ] `M ~ X * C`: treatment absent from the constrained mediator model.
- [ ] `Y ~ X * M + C`: behavior matches §4's ruling — error, or reading (i).
- [ ] The a-branch cancellation of §5 is covered by a comment and a test.
- [ ] `R CMD check --as-cran` 0/0/0; full suite green.
- [ ] NEWS entry says **conservative / power loss**, not "anti-conservative",
      and names the `poly()` case explicitly as the severe one.

## 8. Why this was not fixed before v0.3.0

It is invisible to every gate the package runs. `R CMD check` sees valid
formulas; the test suite only ever exercised `Y ~ X + M + C`; and the defect
produces a *number*, not an error — a smaller number, in a test whose whole
purpose is to produce numbers. Only reading `update()`'s behavior against an
interaction surfaces it. That is an argument for the acceptance criteria above
being tests, not a checklist.
