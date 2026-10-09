# NOTE: the D4 denominator df differs from `mitml` and Chan & Meng (2019)

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Item** | D of [PLAN-open-items-2026-10-09.md](PLAN-open-items-2026-10-09.md) |
| **Status** | FINDING. No code changed; decision pending. |
| **Probe** | [probe-d4-vs-mitml-2026-10-09.R](probe-d4-vs-mitml-2026-10-09.R) (mitml 0.4.5, K = 20 imputations, n = 300) |

## Result

The pooled statistic and the relative increase in variance agree with `mitml::testModels(method = "D4")` to every printed digit. The **denominator degrees of freedom do not**:

| Case | quantity | missingmed | mitml |
|---|---|---|---|
| outcome, drop `M` (k = 1) | F (D4) | 4.30006269229 | 4.3000626923 |
| | r4 / RIV | 0.91612500517 | 0.9161250052 |
| | **nu / df2** | **62.607** | **83.117** |
| | p | 0.04223 | 0.04121 |
| outcome, drop `M` and `X` (k = 2) | F (D4) | 7.703098763 | 7.703098763 |
| | r4 / RIV | 0.4580625026 | 0.4580625026 |
| | **nu / df2** | **324.07** | **385.02** |
| | p | 5.391e-04 | 5.245e-04 |
| `mbco_d4(ariv = "fixed")`, stacked branch `b` | D4, r4 | equal to the k = 1 row above | |

## Cause

- **missingmed** (`R/mbco_mi.R`, `.mm_d4_from_stats`) uses the Li, Raghunathan and Rubin (1991) df, Chan and Meng's eq. 1.6: `nu = 4 + (t - 4) * (1 + (1 - 2/t) / r4)^2` with `t = k (K - 1)` (the other branch for `t <= 4`). It came in with the first hosting commit (`d91aa48`); no spec chose it.
- **mitml** and **Chan and Meng (2019, arXiv 1711.08822)** use `nu = k (K - 1) (1 + 1/r4)^2`, their eq. 2.15 with `h` replaced by `k`. Their Algorithm 2, the standard MI likelihood-ratio test that `mbco_d4()` implements, computes its p-value "according to (2.15)". The paper states that adopting the Li et al. df of eq. 1.6 "leads to a poorer approximation for our purposes".

The two coincide when `k (K - 1) <= 4` (k = 1, K = 5).

## Size of the effect

Li's df is never larger than eq. 2.15, so missingmed's p-values are slightly **conservative** relative to the published procedure. For a nominal 5% test, with `F(1, nu_cm)` as the reference distribution and Li's critical value:

| K | r4 | nu (Li) | nu (eq. 2.15) | size using Li |
|---|---|---|---|---|
| 10 | 0.5 | 36.65 | 81.0 | 0.046 |
| 10 | 1 | 19.8 | 36.0 | 0.044 |
| 20 | 1 | 57.85 | 76.0 | 0.049 |
| 20 | 0.5 | 120.7 | 171.0 | 0.049 |
| 50 | 1 | 176.7 | 196.0 | 0.0499 |

At the K = 20 used in the ML calibration gate (SPEC-sem-mbco section 11) the gap is at most about 0.002, so the reported size (maximum 0.057) would not change materially.

## Consequences

- Not a validity problem: the test is slightly conservative, never liberal, relative to the paper.
- It is a **documentation and parity problem**: the docs say the test follows Chan and Meng, and the 0.4.0 handoff recorded "D4 denominator nu vs mitml's df2: not re-verified". It is now verified, and it differs.
- Switching changes published p-values in the third digit (as above) for the same data, so it needs a NEWS entry.

## Options

1. **Switch to eq. 2.15** (parity with the paper and `mitml`; add a `mitml` parity test; NEWS entry). Cost: XS code, S tests.
2. Keep the Li df, document the deviation and the conservative direction, quote the table above.
3. Offer both through an argument (more surface, no known user need).
