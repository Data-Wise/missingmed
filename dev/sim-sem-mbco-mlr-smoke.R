# Smoke checks for the MLR gate harness; every check can fail.
#   Rscript dev/sim-sem-mbco-mlr-smoke.R        (from the repo root)
source("dev/sim-sem-mbco-mlr-lib.R")
ok <- function(cond, msg) { cat(if (isTRUE(cond)) "PASS " else "FAIL ", msg, "\n", sep = ""); if (!isTRUE(cond)) quit(status = 1) }
mom <- function(x) c(m = mean(x), v = var(x), sk = mean((x - mean(x))^3) / var(x)^1.5,
  ek = mean((x - mean(x))^4) / var(x)^2 - 3)

# 1. Known-answer: the two error laws have mean 0, variance 1 and the textbook
# skewness (chi-square(4): sqrt(2) = 1.414) and excess kurtosis (t(5): 6).
set.seed(1)
s <- mom(err("skewed", 4e6)); h <- mom(err("heavy", 4e6))
ok(abs(s[["m"]]) < .01 && abs(s[["v"]] - 1) < .01 && abs(s[["sk"]] - sqrt(2)) < .03, "skewed errors: mean 0, var 1, skew 1.414")
ok(abs(h[["m"]]) < .01 && abs(h[["v"]] - 1) < .03 && h[["ek"]] > 3, "heavy errors: mean 0, var 1, excess kurtosis well above 0")

# 2. Planted defect: D2 on identical statistics collapses to the single statistic.
ok(abs(d2_p(rep(4, 20), 1) - stats::pchisq(4, 1, lower.tail = FALSE)) < 1e-8, "D2 of identical statistics = chi-square p")
ok(d2_p(c(1, 2, 8, 3, 15, 0.5), 1) > d2_p(rep(mean(c(1, 2, 8, 3, 15, 0.5)), 6), 1), "D2 penalizes between-imputation spread")

# 3. The harness path equals the public one (mbco_d4 + estimator = MLR) on one dataset.
d <- gen_nn("skewed", "observed", 300, 0, .3, .25, 5001)
il <- mice::complete(suppressWarnings(mice::mice(d, m = 20, maxit = 5, method = "norm", printFlag = FALSE, seed = 5001)), "all")
pub <- suppressWarnings(mbco_d4(il, model = "M ~ X + C\nY ~ M + X + C", treatment = "X", mediator = "M",
  outcome = "Y", fit_args = list(estimator = "MLR")))
row <- one_mlr("skewed", "observed", 300, 0, .3, .25, 5001)
ok(is.na(row$err), "one_mlr returns a result, not an error row")
ok(abs(row$p_d4s - unname(pub["p"])) < 1e-8 && abs(row$cd - pub@scaling) < 1e-8, "harness p and scaling equal mbco_d4() under MLR")
ok(if (row$cd > 1) row$p_d4s >= row$p_d4n else row$p_d4s <= row$p_d4n,
  "scaled p is the naive p shifted by cd (cd > 1 shrinks the statistic, so p grows)")

# 4. Every cell type runs: 3 replications each; at least one gives a p-value in
# [0, 1], and the only failure allowed is the documented refusal of a non-positive
# scaling correction (negative SB 2001 differences DO occur in latent cells, e.g.
# seed 5001, skewed latent n = 200, 40% missing: cd = -0.39 in imputation 4; the
# combiner counts them, and the gate reads size next to the refusal rate).
cells <- mlr_cells(ns = 200L, miss = 0.4)
cells <- cells[cells$null == 1, ]
for (i in seq_len(nrow(cells))) {
  cl <- cells[i, ]; ab <- nulls[[cl$null]]
  r <- do.call(rbind, lapply(1:3, function(s) one_mlr(cl$dist, cl$dgp, cl$n, ab[1], ab[2], cl$miss, 5000 + s)))
  good <- is.na(r$err)
  known <- all(grepl("scaled difference test .* is undefined", r$err[!good]))
  ok(any(good) && known && all(r$p_d4s[good] >= 0 & r$p_d4s[good] <= 1) && all(is.finite(r$cd[good])),
    sprintf("cell %s %s n=%d runs (%d of 3 refused)", cl$dist, cl$dgp, cl$n, sum(!good)))
}
cat("smoke OK\n")
