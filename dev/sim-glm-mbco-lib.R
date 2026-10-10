# Shared pieces of the glm-engine MBCO calibration gate
# (SPEC-glm-mbco-calibration-2026-10-09.md). Sourced by sim-glm-mbco-hopper.R
# (SLURM array), sim-glm-mbco-combine.R and sim-glm-mbco-smoke.R. Not part of the
# package build.
if (nzchar(Sys.getenv("SIM_INSTALLED"))) {
  suppressMessages(library(missingmed))
} else {
  suppressMessages(devtools::load_all(".", quiet = TRUE))
}

# (a, b, th) per null id. Ids 1-5 are nulls, id 6 is the power point. `th` is the
# X:M coefficient, used by gauss_xm only; its b-null is b = th = 0.
null_pts <- function(fam) {
  if (fam == "gauss_xm") {
    data.frame(null = 1:6, a = c(0, .3, 0, 0, .1, .3), b = c(.3, 0, 0, .1, 0, .3),
      th = c(.2, 0, 0, .1, 0, .2))
  } else if (fam == "rare_y") {
    data.frame(null = 1:6, a = c(0, .3, 0, 0, .1, .3), b = c(.8, 0, 0, .1, 0, .8), th = 0)
  } else {
    data.frame(null = 1:6, a = c(0, .3, 0, 0, .1, .3), b = c(.3, 0, 0, .1, 0, .3), th = 0)
  }
}

# The 152 cells of the gate, in a fixed order (cell index = row). Cells 1-132 are
# the glm gate; 133-152 are the plain-Gaussian `ariv = "own"` addendum (SPEC section 10).
glm_cells <- function() {
  main <- expand.grid(fam = c("gauss_xm", "bin_y", "pois_y", "bin_m"), n = c(200, 500),
    miss = c(.25, .40), m = 20, null = 1:6, stringsAsFactors = FALSE)
  main$block <- "main"
  rare <- expand.grid(fam = "rare_y", n = c(150, 300), miss = .40, m = 20, null = 1:6,
    stringsAsFactors = FALSE)
  rare$block <- "rare"
  smallk <- expand.grid(fam = c("gauss_xm", "bin_y"), n = 200, miss = .40, m = c(5, 10),
    null = 1:6, stringsAsFactors = FALSE)
  smallk$block <- "smallk"
  gauss <- expand.grid(fam = "gauss", n = c(200, 500), miss = c(.25, .40), m = 20, null = 1:5,
    stringsAsFactors = FALSE)
  gauss$block <- "gauss"
  cells <- rbind(main, rare, smallk, gauss)
  cells <- cells[order(match(cells$block, c("main", "rare", "smallk", "gauss")), cells$fam, cells$n,
    cells$miss, cells$m, cells$null), ]
  rownames(cells) <- NULL
  pts <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
    p <- null_pts(cells$fam[i]); p[p$null == cells$null[i], c("a", "b", "th")]
  }))
  cbind(cells, pts)
}

# One incomplete dataset. Missingness is in the mediator, MAR: logistic in C and Y.
gen_glm <- function(fam, n, a, b, th, miss, seed) {
  set.seed(seed)
  X <- rnorm(n); C <- rnorm(n)
  M <- if (fam == "bin_m") rbinom(n, 1, plogis(a * X + .3 * C)) else a * X + .3 * C + rnorm(n)
  eta <- switch(fam,
    gauss_xm = b * M + th * X * M + .2 * X + .3 * C,
    gauss = b * M + .2 * X + .3 * C,
    bin_y = -.3 + b * M + .2 * X + .3 * C,
    rare_y = -2.6 + b * M + .2 * X + .3 * C,
    pois_y = -.2 + b * M + .2 * X + .3 * C,
    bin_m = b * M + .2 * X + .3 * C)
  Y <- switch(fam,
    gauss_xm = , gauss = eta + rnorm(n),
    bin_y = , rare_y = rbinom(n, 1, plogis(eta)),
    pois_y = rpois(n, exp(eta)),
    bin_m = eta + rnorm(n))
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < plogis(qlogis(miss) + .6 * d$C + .5 * d$Y)] <- NA
  d
}

# Analysis model per family: formulas and families handed to mbco_d4().
spec_glm <- function(fam) {
  switch(fam,
    gauss = list(fy = Y ~ M + X + C, fm = M ~ X + C, gy = stats::gaussian(), gm = stats::gaussian()),
    gauss_xm = list(fy = Y ~ M * X + C, fm = M ~ X + C, gy = stats::gaussian(), gm = stats::gaussian()),
    bin_y = , rare_y = list(fy = Y ~ M + X + C, fm = M ~ X + C, gy = stats::binomial(), gm = stats::gaussian()),
    pois_y = list(fy = Y ~ M + X + C, fm = M ~ X + C, gy = stats::poisson(), gm = stats::gaussian()),
    bin_m = list(fy = Y ~ M + X + C, fm = M ~ X + C, gy = stats::gaussian(), gm = stats::binomial()))
}

NA_ROW <- data.frame(p_fixed = NA_real_, p_own = NA_real_, p_naive = NA_real_, r4 = NA_real_,
  nu = NA_real_, k = NA_real_, branch = NA_character_, refused = NA_character_,
  stringsAsFactors = FALSE)

# One replication: impute, run mbco_d4() under both ariv settings, and derive the
# naive pooled p-value (the positive control of criterion 5) from the same fit.
# A refusal (non-convergence, non-finite likelihood) is recorded, not hidden.
one_glm <- function(cell, seed) {
  d <- gen_glm(cell$fam, cell$n, cell$a, cell$b, cell$th, cell$miss, seed)
  if (cell$fam == "bin_m") d$M <- factor(d$M)
  meth <- mice::make.method(d)
  meth["M"] <- if (cell$fam == "bin_m") "logreg" else "norm"
  imp <- suppressWarnings(mice::mice(d, m = cell$m, maxit = 5, method = meth, printFlag = FALSE, seed = seed))
  il <- mice::complete(imp, "all")
  if (cell$fam == "bin_m") il <- lapply(il, function(x) { x$M <- as.numeric(as.character(x$M)); x })
  sp <- spec_glm(cell$fam)
  run <- function(ariv) tryCatch(
    suppressWarnings(mbco_d4(il, sp$fy, sp$fm, family_y = sp$gy, family_m = sp$gm,
      treatment = "X", mediator = "M", ariv = ariv)),
    error = function(e) conditionMessage(e))
  rf <- run("fixed"); ro <- run("own")
  out <- NA_ROW
  if (is.character(rf)) {
    out$refused <- substr(rf, 1, 80)
    return(out)
  }
  out$p_fixed <- unname(rf[["p"]]); out$r4 <- unname(rf[["r4"]]); out$nu <- unname(rf[["nu"]])
  out$k <- rf@k; out$branch <- rf@stacked_branch
  if (!is.character(ro)) out$p_own <- unname(ro[["p"]])
  # Naive pooling: the mean of the per-imputation statistics referred to
  # chi-square_k. dbar is recovered from the D4 fields: r4 = (K+1)/(k(K-1)) (dbar - d_S).
  K <- cell$m
  dbar <- unname(rf[["d_S"]]) + unname(rf[["r4"]]) * rf@k * (K - 1) / (K + 1)
  out$p_naive <- stats::pchisq(dbar, rf@k, lower.tail = FALSE)
  out
}
