# SPEC: calibration gate for MBCO on the glm engine

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | RUN 2026-10-09 (T1-T4 done). C1, C2, C4, C5 pass; **C3 fails** (one cell); author decision pending. Raw table: [RESULTS-glm-mbco-calibration-2026-10-09.txt](RESULTS-glm-mbco-calibration-2026-10-09.txt). |
| **Plan / grill** | [PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md) item B; [GRILL-open-items-2026-10-09.md](GRILL-open-items-2026-10-09.md) Q2 (re-asked: glm-specific grid) |
| **Predecessor** | ML calibration for lavaan: `SPEC-sem-mbco-2026-10-08.md` section 11 (40 cells, max size 0.057) |
| **Measures** | the procedure as of `dev` `fb17b60`: D4 with Chan and Meng eq. 2.15 denominator df (#62) |
| **Size** | M (harness S, hopper run, report S) |

## 1. Why this gate, and why not the lavaan grid

The glm engine is the default MBCO path and has the least calibration evidence in the package: a prototype at n = 200, m = 5, 300 replications (size 0.050 at one single-null cell, 0.007 at the intersection). The lavaan gate does not transfer:

- Its observed-variable cells are Gaussian, where glm and lavaan agree to about 1e-10 (the parity test). Rerunning them on glm adds nothing.
- Its latent cells cannot run on glm.
- It never exercised **k > 1** (a Gaussian `X:M` outcome model removes both `M` and `X:M`, k = 2), **non-Gaussian families**, or **near-separated fits that still converge** (118 of 400 near-separated fits converge with finite likelihoods and are not refused; `SPEC-mbco-convergence-2026-10-08.md`, C6).
- It ran at K = 20 only. The denominator-df change of #62 matters most at small K and k > 1.

## 2. Design

Fixed as in the ML gate: MAR missingness in the mediator (logistic in `C` and `Y`), `mice` imputation, `ariv = "fixed"` gated, seeds `5000 + replication`, 1000 replications per cell, 5% level, Monte Carlo se about 0.007. Normal `X ~ N(0, 1)`, `C ~ N(0, 1)`.

**Families (the DGP and the analysis model share the family).** `a` is the `X -> M` coefficient, `b` the `M -> Y` coefficient, `th` the `X:M` coefficient.

| Id | Mediator model | Outcome model | k of the winning branch |
|---|---|---|---|
| `gauss_xm` | `M = a X + .3 C + e`, Gaussian | `Y = b M + th X M + .2 X + .3 C + e`, Gaussian, outcome formula `Y ~ M * X + C` | 1 (a = 0) or **2** (b = 0 drops `M` and `X:M`) |
| `bin_y` | Gaussian | `Y ~ Bernoulli(plogis(-.3 + b M + .2 X + .3 C))` | 1 |
| `pois_y` | Gaussian | `Y ~ Poisson(exp(-.2 + b M + .2 X + .3 C))` | 1 |
| `bin_m` | `M ~ Bernoulli(plogis(a X + .3 C))`, imputed by `logreg` | Gaussian | 1 |
| `rare_y` (near-separation) | Gaussian | `bin_y` with intercept -2.6 (about 7-10% events) | 1 |

For `gauss_xm` the b-null is `b = th = 0` (otherwise `a (b + th x)` is not zero), so its nulls are `(a, b, th)`: `(0, .3, .2)`, `(.3, 0, 0)`, `(0, 0, 0)`, `(0, .1, .1)`, `(.1, 0, 0)`, power `(.3, .3, .2)`. Other families use `(a, b)` with the same five nulls as the ML gate plus the power point `(.3, .3)`. `rare_y` uses `b = .8` where the others use `.3`, so the event-poor outcome still carries a strong path.

**Cells.**

| Block | Families | n | Missing | m | Nulls | Cells |
|---|---|---|---|---|---|---|
| Main | `gauss_xm`, `bin_y`, `pois_y`, `bin_m` | 200, 500 | 25%, 40% | 20 | 6 | 96 |
| Near-separation | `rare_y` | 150, 300 | 40% | 20 | 6 | 12 |
| Small K | `gauss_xm`, `bin_y` | 200 | 40% | 5, 10 | 6 | 24 |
| | | | | | **Total** | **132** |

Per replication the harness records `p` under `ariv = "fixed"` and under `"own"`, `r4`, `nu`, `k`, the winning branch, and whether the replication was **refused** (non-convergence, non-finite likelihood), with the refusal's reason. Size is computed over replications that returned a p-value; the refusal share is reported beside it, because conditioning on non-refusal can bias size.

## 3. Pass criteria (fixed before the run)

Each can fail. Report per cell, never pooled.

1. **Type I control.** Size at the 5% level is at most **6.5%** in every null cell (`ariv = "fixed"`), including the intersection and near-intersection cells; conservative is allowed and reported. This is the restated ML-gate criterion (D3), with no lower band: single-null sizes are reported with their Monte Carlo se.
2. **Small K.** The same 6.5% bound holds in the `m = 5` and `m = 10` cells (the cells where the df change is largest).
3. **The test is not dead.** Power at the power point is reported per cell and is at least 50% in the n = 500 main cells; a vacuous always-accept test would otherwise pass criterion 1.
4. **Refusals.** In the main and small-K blocks the refusal share is at most 1% per cell; above that, investigate before reading size. `rare_y` refusal shares are reported without a bound (refusing is the designed behavior there).
5. **Positive control (planted defect).** Every replication also records the naive pooled p-value (the mean of the per-imputation statistics referred to `chi-square_k`, the rule `vignette("technical")` shows is anti-conservative), derived from the same fit. The gate is valid only if the naive test shows size **above 6.5%** in the `bin_y`, n = 200, 40% missing, single-null cells `(0, .3)` and `(.3, 0)`; otherwise the harness cannot see liberal behavior and the run is void. (Folded into the main cells, so it costs no extra replications.)
6. **`ariv = "own"` is reported**, not gated: it is the 0.4.0 behavior and is documented as such.

**If a cell fails criterion 1 or 2:** rerun that cell with 3000 replications (se about 0.004) to separate noise from bias; if confirmed, do not change the procedure inside the gate. Document the limitation in `?mbco_d4` and NEWS and open its own spec for the fix.

## 4. Harness and hopper

Standing rule: large simulations run on hopper through a SLURM array, piloted through `sbatch` (memory `large-sims-go-to-hopper`; account 2016507, `~/Rlib-sem`, `module load r/4.4.0-ytj2` after `source /etc/profile.d/modules.sh`, array index at most 2000 and at most 512 queued tasks).

New files, separate from the archived lavaan harness: `dev/sim-glm-mbco-lib.R` (generators, `one()`), `dev/sim-glm-mbco-hopper.R` (task id to cell and chunk), `dev/sim-glm-mbco-combine.R`, `dev/sim-glm-mbco.sbatch`. `CHUNKS = 3`, so 132 cells x 3 = 396 tasks (under 512), 333 replications per task. Measured in the smoke test (T2): about 0.15 s per replication, so a task takes about a minute and the whole array well under an hour of cluster time.

## 5. Tasks

| Task | Scope | Size |
|---|---|---|
| T1 | DONE. Harness: generators, `one_glm()` recording the fields of section 2, the naive-pooling control, combine script | S |
| T2 | DONE. Local smoke (`dev/sim-glm-mbco-smoke.R`): each family, 3 replications, the recorded fields, `gauss_xm` reaching k = 2, the naive control inflating (0.100 vs 0.025 at 120 replications) | XS |
| T3 | Pilot on hopper: `sbatch --array=1-1` with `REPS = 20` for one cell per block | XS |
| T4 | Full array on hopper (396 tasks) and combine | S (wall time) |
| T5 | Report: new section 12 in `SPEC-sem-mbco-2026-10-08.md` or a results note here; the operating-characteristics table in `vignettes/mbco-mi.Rmd` gains the glm rows if the gate passes | S |

Checkpoint after T2 (the naive control inflates, k = 2 appears) and after T3 (the harness runs under SLURM) before T4.

## 6. Not in scope

- `fit_args` for the glm MBCO refits. They never reach `.mm_glm_ll` (`R/mbco_mi.R`): the calibration measures the default `glm()` settings, which is also what users get. Passing them through, or documenting the limit, is a separate item (memory `mbco-glm-refits-ignore-fit-args`).
- MLR (item C), IPW with MBCO (refused by design), non-Gaussian `X:M` models (refused by `set_md_mediation()`; `mbco_d4()` on a plain list is not part of the product claim for those).
- `engine = "regmedint"` (MBCO refits it with glm; covered by the same code path).

## 7. Risks

| Risk | Mitigation |
|---|---|
| `bin_m` imputation by `logreg` is itself slow or unstable at n = 200 | T2 smoke; if the refusal share exceeds the bound, report it as a finding rather than tune the DGP |
| `rare_y` produces more refusals than informative replications | That is the point of the block; size is reported with the refusal share, and the cell is not gated on criterion 4 |
| One cell exceeds 6.5% by chance | About 44 of the cells are single-null cells with true size near 5%; at 1000 replications each has about a 1.5% chance of exceeding 6.5% (se 0.007), so expect under one such cell by chance. The 3000-replication rerun in section 3 separates noise from bias |
| The control cells do not inflate | Criterion 5 voids the run; the harness is fixed, not the procedure |

## 8. Results (2026-10-09)

Hopper job 4333687: 396 tasks, all COMPLETED, 132 cells x 1000 replications (131,997 replications reported by the combine script; 0.0-0.4% refused). Package: missingmed 0.8.0.9000 built from `dev` (`0e1ca7e`, with the Chan and Meng denominator df of #62). Pilot (T3): job 4333675, 12 tasks. Cell-level table: [RESULTS-glm-mbco-calibration-2026-10-09.txt](RESULTS-glm-mbco-calibration-2026-10-09.txt).

| Criterion | Outcome |
|---|---|
| C1 size at most 6.5% in every null cell (`fixed`) | **PASS**: 110 of 110 cells, maximum **0.057** (`gauss_xm`, n = 500, 25%, (0, .3, .2)). Mean size over single-null cells 0.034-0.036; intersection 0.003; near-intersection 0.009-0.011 |
| C2 same bound at m = 5 and 10 | **PASS**: maximum 0.046 (`bin_y`, m = 5) |
| C3 power at least 50% in n = 500 main cells | **FAIL as written**: 15 of 16 cells pass; `bin_m`, n = 500, 40% missing has power **0.433** (the same family at 25% missing: 0.593) |
| C4 refusals at most 1% (main, small K) | **PASS**: 0.000 everywhere; `rare_y` refusals 0-0.4% (reported) |
| C5 positive control | **PASS**: the naive pooled test has size 0.111 and 0.244 in the `bin_y`, n = 200, 40% single-null cells, and 0.12-0.34 across single-null cells generally. The harness sees liberal behavior |
| C6 `ariv = "own"` (reported) | **Liberal in 23 of 110 null cells**, up to **0.138** (`pois_y`, n = 200, 40%, (.3, 0)); mostly non-Gaussian families at 40% missing. See below |

**C3.** The pre-registered bound is missed by one cell, and the miss is about power, not validity. A binary mediator with `a = .3` on the log-odds scale carries little information, and power falls with missingness (0.593 at 25%, 0.433 at 40%) and rises with n (0.101 at n = 200, 40%). Nothing in the data suggests a dead test: the test rejects 99-100% in the `gauss_xm` n = 500 power cells and 90-98% in `pois_y`. Under the rule that each criterion can fail, this one did; it is reported as a FAIL, not restated.

**Type I error.** The default (`ariv = "fixed"`) is conservative throughout: single-null cells average about 3.5%, never above 5.7%. That matches the lavaan result (maximum 0.057, single-null mean 4.2%). The k = 2 branch (`gauss_xm`, b = th = 0 nulls) is covered: mean k = 1.95 in the b-null cells, sizes 0.037-0.050 there.

**`ariv = "own"`.** The 0.4.0-compatible setting exceeds 6.5% in 23 of 110 null cells (maximum 0.138), concentrated in `pois_y` and the binary-outcome cells at 40% missing, while `fixed` stays at or below 5.7% on the same replications. This is the first calibration evidence on `"own"`; it supports the default and argues for a documentation warning (see Decisions).

## 9. Decisions (author)

1. **C3**: accept the FAIL as a reported power finding (recommended), or add a strong-effect power cell for `bin_m` (`a = .6`) to show the test is not dead there.
2. **`ariv = "own"`**: document that it can be liberal for non-Gaussian families at high missingness and that `"fixed"` is the calibrated default (`?mbco_d4`, `mbco-mi`, NEWS), recommended; no behavior change.
3. The operating-characteristics table in `vignettes/mbco-mi.Rmd` gains the glm rows (the lavaan rows are already there).
