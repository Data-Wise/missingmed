# Bootstrap oracle for the stacked IPW variance (E step 3,
# docs/specs/NOTE-ipw-weight-score-stacking-2026-10-09.md section 6.2).
# Nonparametric bootstrap of the WHOLE pipeline (re-estimate the weights, apply
# the trim, refit) against the analytic stacked SE and the known-weights SE.
# Usage: Rscript dev/ipw-stack-oracle.R [B] [out.rds]   (B default 500)
# Pre-registered bar: stacked SE / bootstrap SE in [0.90, 1.10] for a and b in
# every dataset and configuration (bootstrap se of an SE is about 1/sqrt(2B) = 3%
# at B = 500), and |corr_stacked(a, b) - corr_boot(a, b)| < 0.10.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
args <- commandArgs(TRUE)
B <- if (length(args) >= 1L) as.integer(args[1]) else 500L
out <- if (length(args) >= 2L) args[2] else NULL

# dgm = "std": missingness driven by X and C, which both regressions contain, so
# the weights are nearly ignorable and the weight-score term is small.
# dgm = "aux": missingness driven mainly by an auxiliary Z that affects M and Y but
# is left out of the regressions (marginal models), the setting where estimating
# the weights changes the variance.
gen <- function(seed, n = 500, dgm = "std") {
  set.seed(seed)
  C <- rnorm(n); Z <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  zc <- if (dgm == "aux") 0.7 else 0
  M <- 0.5 * X + 0.3 * C + zc * Z + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + zc * Z + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C, Z = Z)
  if (dgm == "aux") {
    d$M[plogis(-0.9 + 1.2 * Z) > runif(n)] <- NA
    d$Y[plogis(-1.4 + 1.0 * Z) > runif(n)] <- NA
  } else {
    d$M[plogis(-0.9 + 0.5 * d$X + 0.5 * d$C) > runif(n)] <- NA
    d$Y[plogis(-1.4 + 0.5 * d$X + 0.4 * d$C) > runif(n)] <- NA
  }
  d
}

configs <- list(
  aux_unstab = list(dgm = "aux", weight_stabilize = FALSE, weight_formula = ~ X + C + Z),
  aux_stab = list(dgm = "aux", weight_stabilize = TRUE, weight_formula = ~ X + C + Z),
  aux_stab_trim = list(dgm = "aux", weight_stabilize = TRUE, weight_formula = ~ X + C + Z,
    weight_trim = 0.95),
  aux_stab_pervar = list(dgm = "aux", weight_stabilize = TRUE,
    weight_formula = list(M = ~ X + C + Z, Y = ~ X + C + Z)),
  unstab_joint = list(weight_stabilize = FALSE, weight_formula = ~ X + C),
  stab_joint = list(weight_stabilize = TRUE, weight_formula = ~ X + C),
  stab_pervar = list(weight_stabilize = TRUE, weight_formula = list(M = ~ X + C, Y = ~ X + C)),
  stab_joint_trim = list(weight_stabilize = TRUE, weight_formula = ~ X + C, weight_trim = 0.95)
)

fit_one <- function(d, cfg) {
  cfg$dgm <- NULL
  md <- suppressWarnings(do.call(set_md_mediation, c(
    list(d, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M", method = "ipw"), cfg)))
  ii <- missingmed:::.ipw_weights_info(md)
  cc <- ii$info$cc
  fits <- list(
    m = stats::glm(M ~ X + C, data = d[cc, ], weights = ii$w[cc]),
    y = stats::glm(Y ~ X + M + C, data = d[cc, ], weights = ii$w[cc])
  )
  list(fits = fits, info = ii$info)
}
ab <- function(fits) c(a = unname(stats::coef(fits$m)["X"]), b = unname(stats::coef(fits$y)["M"]))

res <- list()
for (cn in names(configs)) for (seed in 1:5) {
  d <- gen(100 + seed, dgm = if (is.null(configs[[cn]]$dgm)) "std" else configs[[cn]]$dgm)
  f <- fit_one(d, configs[[cn]])
  V <- missingmed:::.ipw_stacked_vcov(f$fits, f$info)
  i0 <- f$info; i0$blocks <- list()
  V0 <- missingmed:::.ipw_stacked_vcov(f$fits, i0)
  ia <- which(colnames(V) == "m:X"); ib <- which(colnames(V) == "y:M")
  set.seed(1000 + seed)
  bt <- matrix(NA_real_, B, 2)
  for (r in seq_len(B)) {
    db <- d[sample(nrow(d), replace = TRUE), ]
    bt[r, ] <- tryCatch(ab(fit_one(db, configs[[cn]])$fits), error = function(e) c(NA, NA))
  }
  ok <- stats::complete.cases(bt)
  bse <- apply(bt[ok, , drop = FALSE], 2, stats::sd)
  rb <- stats::cor(bt[ok, 1], bt[ok, 2])
  res[[length(res) + 1L]] <- data.frame(
    config = cn, seed = seed, n_cc = sum(f$info$cc), n_trim = sum(f$info$trimmed),
    ok = sum(ok),
    ratio_a_stacked = sqrt(V[ia, ia]) / bse[1], ratio_b_stacked = sqrt(V[ib, ib]) / bse[2],
    ratio_a_known = sqrt(V0[ia, ia]) / bse[1], ratio_b_known = sqrt(V0[ib, ib]) / bse[2],
    corr_stacked = V[ia, ib] / sqrt(V[ia, ia] * V[ib, ib]), corr_boot = rb
  )
  cat(cn, seed, "done\n")
}
res <- do.call(rbind, res)
res$pass <- with(res, ratio_a_stacked >= .9 & ratio_a_stacked <= 1.1 &
  ratio_b_stacked >= .9 & ratio_b_stacked <= 1.1 & abs(corr_stacked - corr_boot) < .1)
print(format(res, digits = 3), row.names = FALSE)
cat("\nPASS", sum(res$pass), "of", nrow(res), "\n")
cat("\nMeans by config (SE ratio to bootstrap; correlation of a and b):\n")
print(aggregate(cbind(ratio_a_stacked, ratio_a_known, ratio_b_stacked, ratio_b_known,
  corr_stacked, corr_boot) ~ config, res, function(x) round(mean(x), 3)), row.names = FALSE)
cat("stacked closer to bootstrap than known-weights (a, b):",
  sum(abs(log(res$ratio_a_stacked)) < abs(log(res$ratio_a_known))),
  sum(abs(log(res$ratio_b_stacked)) < abs(log(res$ratio_b_known))), "of", nrow(res), "\n")
if (!is.null(out)) saveRDS(res, out)
