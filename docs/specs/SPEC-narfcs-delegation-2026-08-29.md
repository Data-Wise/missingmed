# SPEC: NARFCS delegation for `sensitivity_mnar()`

| | |
|---|---|
| **Status** | draft |
| **Created** | 2026-08-29 |
| **Supersedes** | `SPEC-mnar-sensitivity-2026-08-22.md` §3.0 (the OPEN FORK) |
| **Blocks** | nothing — v0.3.0 ships without this |
| **Target** | v0.4.0 |

## Why this reopens a settled decision

`SPEC-mnar-sensitivity-2026-08-22.md` §3.0 chose to hand-roll delta adjustment
through `mice`'s `post` argument and rejected NARFCS delegation on one stated
ground:

> Dependency | none | **GitHub-only, not on CRAN** — hostile to a CRAN-targeted package

**That ground is factually stale.** NARFCS is not GitHub-only. `mice` itself
exports `mice.impute.mnar.norm()` and `mice.impute.mnar.logreg()` (Moreno-Betancur,
van Buuren & White 2020), driven by the `blots` argument. `mice` is already a hard
`Imports:` dependency, so delegation adds **no** new dependency. `mice`'s own
documentation describes `moreno-betancur/NARFCS` as the *old* version.

The rest of §3.0's analysis stands and is not disturbed here — in particular the
CSP/MSP gap (Tompsett et al. 2018) and the reporting of realized `msp`, which
remain necessary under either mechanism.

## Finding that decides the design: the two mechanisms are the SAME for `norm`

Verified 2026-08-29 (R 4.6.1, mice 3.19.0), n = 500, 35% missing on `M`,
`delta = 2`, m = 5, maxit = 5, **same seed**:

| Path | realized msp |
|---|---|
| A — `post`, shift the drawn value (current implementation) | 1.964489 |
| B — `mice.impute.mnar.norm`, `blots = list(M = list(ums = "2"))` | 1.964489 |

`max(abs(A$imp$M - B$imp$M)) = 8.88e-16` — floating-point noise, not agreement
in distribution but **identical draws**.

The source explains it. `mice.impute.mnar.norm` is

```r
x[wy, ] %*% parm$beta + u$x[wy, ] %*% u$delta + rnorm(sum(wy)) * parm$sigma
```

For a constant `ums`, `u$x %*% u$delta` is a scalar added to the linear
predictor of a normal draw — arithmetically the same as adding it to the drawn
value afterwards. So the current `post` implementation is **not an approximation
of NARFCS for continuous targets; it is NARFCS**, reached by a different route.

**Consequence for this spec:** delegation is not a correctness fix for the
`norm` case. It is a capability extension. That reframes the whole decision, and
it means §2's `pmm` caveat in the MNAR spec is the *only* place the two paths
diverge on a target the package currently accepts.

## Capability matrix (all rows verified empirically)

| Capability | `post` (current) | mice NARFCS |
|---|---|---|
| Constant delta, `norm` target | ✅ | ✅ **provably identical** |
| Constant delta, `pmm` target | ✅ (with a caveat message) | ❌ **no `mice.impute.mnar.pmm`** |
| Binary / categorical target | ❌ refused, "not yet implemented" | ✅ `mnar.logreg`, delta on the **log-odds** scale |
| Covariate-varying delta | ❌ | ✅ `ums = "1 + 2*X"` |
| Auxiliary variable outside the imputation model | ❌ | ✅ `umx` |

Binary target, verified (n = 600, 35% missing on a binary `M`, m = 5, seed 7):

| log-odds delta | prevalence among imputed |
|---|---|
| MAR baseline (`logreg`) | 0.5479 |
| 0 (`mnar.logreg`) | 0.5479 |
| 1 | 0.7592 |
| 2 | 0.8872 |

The `delta = 0` rung reproduces the MAR baseline exactly, so the package's
central guarantee survives delegation for this method. (§3.0 of the prior spec
worried it would not; that worry was about the *external* NARFCS extension's
reparameterization, and does not apply to `mnar.logreg` with `ums = "0"`.)

## Design: hybrid routing, not wholesale replacement

Delegating everything would **drop `pmm`** — the current default path for a
continuous mediator. So route per target method:

| Baseline `mids$method[block]` | Mechanism | Delta scale |
|---|---|---|
| `norm`, `norm.nob`, `norm.boot`, `norm.predict` | `mnar.norm` via `blots` | raw units of the target |
| `logreg`, `logreg.boot` | `mnar.logreg` via `blots` | **log-odds** |
| `pmm`, `midastouch`, `cart`, `rf`, everything else | `post` (today's path) | raw units, applied to the drawn value |

Rationale for keeping `post` rather than switching `pmm` to `norm`: silently
changing the user's imputation method is a bigger intervention than shifting
its output, and the `pmm` caveat is already documented and messaged.

### API

No new function. Two new arguments on `sensitivity_mnar()`:

- `scale = c("auto", "raw", "logodds")` — reporting only; `auto` derives from the
  routed mechanism. Print/`tidy()` must state the scale, because a delta of 1
  means something different per row of the routing table.
- `ums` — optional character, passed through to `blots` verbatim for the
  covariate-varying case. Mutually exclusive with `delta`; when given, the grid
  is a character vector of `ums` strings, one per rung.

`@mechanism_used` (character, one of `"post"`, `"mnar.norm"`, `"mnar.logreg"`)
joins `MDSensitivityResult` and appears in `print()`. Users must be able to see
which path ran without reading source.

### Implementation notes (each verified)

1. **`blots` composition, not replacement.** A user's existing
   `blots[[v]]` (e.g. `list(donors = 3)`) must be preserved — verified that
   `mids$blots` round-trips. Merge `ums`/`umx` into the target's list; do not
   overwrite the element.
2. **Method substitution per rung.** Routing to `mnar.norm` means passing
   `method` with the target's entry changed. `method` is keyed by **block**
   (see PR #7 finding 2) — resolve through `.mnar_block_of()`, never by
   variable name.
3. **`ums` needs an intercept term.** `parse.ums()` errors without one, and
   accepts at most one. Generate `as.character(delta)` for the constant case.
4. **`umx` is a matrix argument**, columns named for the variables the `ums`
   references. Verified working for an auxiliary column absent from the
   imputation model.
5. **The categorical guard at `.mnar_check_targets()` inverts.** It currently
   *refuses* factor/`logreg` targets; under this spec those become the
   `mnar.logreg` route. Keep refusing `polyreg`/`polr`/`lda` — mice ships no
   multinomial/ordinal NARFCS method.
6. **mice floor stays `>= 3.18.0`** (already raised in PR #7). `mnar.norm`
   predates that, so no further bump.

## Acceptance criteria

- [ ] Continuous `norm` target: `mnar.norm` and `post` rungs agree to `< 1e-12`
      on the same seed — a regression test pinning the equivalence above.
- [ ] Binary target: `sensitivity_mnar()` runs instead of erroring; `delta = 0`
      reproduces the MAR baseline prevalence exactly.
- [ ] `pmm` target: still routed through `post`, existing tests unchanged.
- [ ] `polyreg`/`polr`/`lda` targets: still refused, message updated to say the
      binary case is now supported.
- [ ] `print()` and `tidy()` state the delta scale and `@mechanism_used`.
- [ ] A user's pre-existing `blots` entry survives every rung.
- [ ] Vignette section: when a log-odds delta of 1 is and is not plausible —
      the categorical analogue of the CSP/MSP caution.
- [ ] `R CMD check --as-cran` 0/0/0; no new exports (so `_pkgdown.yml` untouched).

## What this does NOT do

- **No CSP calibration.** Reporting realized `msp` stays the only bridge between
  the conditional parameter the user sets and the marginal one they mean
  (Tompsett et al. 2018). Delegation does not close that gap.
- **No multinomial or ordinal targets.** mice has no NARFCS method for them.
- **No claim of new methodology.** NARFCS is Tompsett et al. (2018); the mice
  implementation is Moreno-Betancur, van Buuren & White (2020). missingmed's
  contribution is wiring the delta curve to an *indirect effect*, which remains
  the package-level gap — no R package combines missing-data handling, causal
  mediation, and MNAR sensitivity (prior-art scan, 2026-08-29).

## References

- Tompsett, Leacy, Moreno-Betancur, Heron & White (2018). *Stat Med* 37(15):
  2338–2353. DOI 10.1002/sim.7643 — canonical NARFCS.
- Leacy, Floyd, Yates & White (2017). *Am J Epidemiol* 185(4): 304–315.
  DOI 10.1093/aje/kww107 — MI + delta on a partially observed mediator in
  parametric causal mediation; the closest published precedent.
- Moreno-Betancur, van Buuren & White (2020) — the mice implementation.
- van Buuren, *FIMD* §9.2.3 — delta adjustment.
