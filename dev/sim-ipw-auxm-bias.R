# Where does the `auxm` bias in b come from? (docs/specs/SPEC-ipw-stack-coverage-2026-10-09.md
# section 14.) Laptop script, a few minutes: Rscript dev/sim-ipw-auxm-bias.R
#   Part 1: mean b at n from 500 to 1e5 for full data, unweighted complete cases, the TRUE
#           weights of the DGM, and the package's per-variable (spv) and joint (uj, sj) weights.
#   Part 2: decay of the spv bias, 300 replications per n.
# Cell: auxm, a = b = .3 (P4), 40% missing in each of M and Y. Nominal b = 0.30.
source("dev/sim-ipw-stack-lib.R")
cl <- ipw_cells(); cl <- cl[cl$dgm == "auxm" & cl$n == 500 & cl$miss == .40 & cl$point == "P4", ][1, ]
p <- ipw_dgms$auxm
bfit <- function(d, w) unname(coef(lm(Y ~ X + M + C, data = d, weights = w))["M"])
cat(sprintf("missingmed %s, auxm P4 miss = 0.40, nominal b = 0.30\n\n", packageVersion("missingmed")))
cat("PART 1: mean b by weights\n")
for (n in c(500, 5000, 2e4, 1e5)) {
  reps <- if (n <= 5000) 40 else 8
  out <- t(sapply(seq_len(reps), function(s) {
    d <- gen_ipw("auxm", n, cl$a, cl$b, cl$miss, cl$alpha, seed = 31000 + s)
    full <- gen_ipw("auxm", n, cl$a, cl$b, cl$miss, cl$alpha, seed = 31000 + s, complete = TRUE)
    cc <- complete.cases(d); dc <- d[cc, ]
    w_true <- 1 / (1 - plogis(cl$alpha + p$s_z * d$Z))^2   # P(M and Y observed | Z) = (1 - pi)^2
    c(full = unname(coef(lm(Y ~ X + M + C, full))["M"]), unweighted = bfit(dc, NULL),
      true_w = bfit(dc, w_true[cc]),
      spv = unname(coef(ipw_fit(d, ipw_forms$spv)$fits$y)["M"]),
      uj = unname(coef(ipw_fit(d, ipw_forms$uj)$fits$y)["M"]),
      sj = unname(coef(ipw_fit(d, ipw_forms$sj)$fits$y)["M"]),
      ess = sum(w_true[cc])^2 / sum(w_true[cc]^2) / sum(cc))
  }))
  m <- colMeans(out)
  cat(sprintf("n=%6d reps=%2d  full %.3f | unweighted cc %.3f | TRUE weights %.3f | spv %.3f | uj %.3f | sj %.3f  (ESS/n_cc %.2f)\n",
    n, reps, m["full"], m["unweighted"], m["true_w"], m["spv"], m["uj"], m["sj"], m["ess"]))
}
cat("\nPART 2: decay of the spv bias (300 replications per n)\n")
for (n in c(200, 500, 1000, 2000, 5000)) {
  b <- vapply(seq_len(300), function(s) {
    d <- gen_ipw("auxm", n, cl$a, cl$b, cl$miss, cl$alpha, seed = 41000 + s)
    unname(coef(ipw_fit(d, ipw_forms$spv)$fits$y)["M"])
  }, 0)
  cat(sprintf("n=%5d spv b: mean %.3f (se %.3f), median %.3f, sd %.3f\n", n, mean(b), sd(b) / sqrt(300), median(b), sd(b)))
}
