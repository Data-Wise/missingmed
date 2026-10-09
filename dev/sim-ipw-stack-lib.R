# Shared pieces of the coverage gate for the stacked IPW variance
# (SPEC-ipw-stack-coverage-2026-10-09.md). Sourced by sim-ipw-stack-hopper.R
# (SLURM array), sim-ipw-stack-combine.R and sim-ipw-stack-smoke.R. Not part of
# the package build.
if (nzchar(Sys.getenv("SIM_INSTALLED"))) {
  suppressMessages(library(missingmed))
} else {
  suppressMessages(devtools::load_all(".", quiet = TRUE))
}

# Auxiliary Z: effect on the mediator (zm) and on the outcome (zy), and the
# slopes of the missingness logit on X, C and Z. M and Y share the slopes and the
# intercept. `joint = FALSE`: M and Y are missing independently given the drivers
# (the joint complete-case model is then misspecified; only `spv` is correct).
# `joint = TRUE`: they are missing together, one Bernoulli per row (the joint forms
# are then correct and `spv` is not). SPEC-ipw-stack-hc-gate-2026-10-09.md section 2.
ipw_dgms <- list(
  std = list(zm = 0, zy = 0, s_x = .5, s_c = .5, s_z = 0, joint = FALSE),
  aux = list(zm = 0, zy = .7, s_x = 0, s_c = 0, s_z = 1, joint = FALSE),
  auxm = list(zm = .7, zy = .7, s_x = 0, s_c = 0, s_z = 1, joint = FALSE),
  stdj = list(zm = 0, zy = 0, s_x = .5, s_c = .5, s_z = 0, joint = TRUE),
  auxj = list(zm = 0, zy = .7, s_x = 0, s_c = 0, s_z = 1, joint = TRUE),
  auxmj = list(zm = .7, zy = .7, s_x = 0, s_c = 0, s_z = 1, joint = TRUE)
)
# Weight forms whose missingness model is correct in each DGM: only these decide.
ipw_decisive <- list(std = "spv", aux = "spv", auxm = "spv",
  stdj = c("uj", "sj", "sjt"), auxj = c("uj", "sj", "sjt"), auxmj = c("uj", "sj", "sjt"))

# (a, b) of the complete-data population regressions M ~ X + C and Y ~ X + M + C.
ipw_points <- data.frame(point = c("P1", "P2", "P3", "P4"),
  a = c(0, .3, 0, .3), b = c(.3, 0, 0, .3), stringsAsFactors = FALSE)

# Drivers of the missingness model, drawn once to solve the intercepts.
ipw_drivers <- function(n) {
  C <- rnorm(n); Z <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  list(X = X, C = C, Z = Z)
}

# Intercept that gives each of M and Y the stated marginal missing share.
ipw_intercept <- function(dgm, miss) {
  set.seed(20261009)
  v <- ipw_drivers(2e5); p <- ipw_dgms[[dgm]]
  lin <- p$s_x * v$X + p$s_c * v$C + p$s_z * v$Z
  stats::uniroot(function(al) mean(plogis(al + lin)) - miss, c(-10, 10), tol = 1e-12)$root
}

# The 96 cells, in a fixed order (cell index = row).
ipw_cells <- function() {
  cells <- expand.grid(dgm = names(ipw_dgms), n = c(200, 500), miss = c(.25, .40),
    point = ipw_points$point, stringsAsFactors = FALSE)
  cells <- cells[order(match(cells$dgm, names(ipw_dgms)), cells$n, cells$miss,
    match(cells$point, ipw_points$point)), ]
  rownames(cells) <- NULL
  pt <- ipw_points[match(cells$point, ipw_points$point), c("a", "b")]
  rownames(pt) <- NULL
  al <- unlist(Map(ipw_intercept, cells$dgm, cells$miss))
  cbind(cells, pt, alpha = unname(al))
}

# One incomplete dataset. `b_correct = FALSE` is the planted defect of the T1
# check: it leaves the structural b uncorrected for the auxiliary variable.
gen_ipw <- function(dgm, n, a, b, miss, alpha, seed, b_correct = TRUE, complete = FALSE) {
  p <- ipw_dgms[[dgm]]
  set.seed(seed)
  v <- ipw_drivers(n)
  M <- a * v$X + .3 * v$C + p$zm * v$Z + rnorm(n)
  b_s <- if (b_correct) b - p$zy * p$zm / (1 + p$zm^2) else b
  Y <- b_s * M + .2 * v$X + .3 * v$C + p$zy * v$Z + rnorm(n)
  d <- data.frame(X = v$X, M = M, Y = Y, C = v$C, Z = v$Z)
  if (complete) return(d)
  lin <- alpha + p$s_x * d$X + p$s_c * d$C + p$s_z * d$Z
  if (p$joint) {
    r <- runif(n) < plogis(lin)
    d$M[r] <- NA; d$Y[r] <- NA
  } else {
    d$M[runif(n) < plogis(lin)] <- NA
    d$Y[runif(n) < plogis(lin)] <- NA
  }
  d
}

# Population truth per (dgm, point), stored by `smoke --write-defs` and read by
# one_ipw(); there is no silent fallback to the nominal values.
ipw_truth_file <- "dev/sim-ipw-stack-truth.rds"
ipw_truth_table <- function() {
  if (!file.exists(ipw_truth_file)) stop(ipw_truth_file, " is missing; run smoke --write-defs", call. = FALSE)
  readRDS(ipw_truth_file)
}

# Complete-data population (a, b): the quantities IPW targets.
ipw_truth <- function(cell, N = 2e6, b_correct = TRUE) {
  d <- gen_ipw(cell$dgm, N, cell$a, cell$b, cell$miss, cell$alpha, seed = 777,
    b_correct = b_correct, complete = TRUE)
  c(a = unname(stats::coef(stats::lm(M ~ X + C, d))["X"]),
    b = unname(stats::coef(stats::lm(Y ~ X + M + C, d))["M"]))
}

# The four weight forms evaluated on every replication (spec section 2). All use a
# missingness model with every driver (X, C, Z), so it is correctly specified.
ipw_forms <- list(
  uj = list(weight_stabilize = FALSE, weight_formula = ~ X + C + Z),
  sj = list(weight_stabilize = TRUE, weight_formula = ~ X + C + Z),
  sjt = list(weight_stabilize = TRUE, weight_formula = ~ X + C + Z, weight_trim = 0.95),
  spv = list(weight_stabilize = TRUE, weight_formula = list(M = ~ X + C + Z, Y = ~ X + C + Z))
)

# Weighted glm fits on the complete cases for one weight form, plus the info the
# stacked variance needs. Errors (a refit that fails, a refused weight model) are
# returned as a message, not thrown, so the replication is recorded, not dropped.
ipw_fit <- function(d, cfg) {
  tryCatch({
    md <- suppressWarnings(do.call(set_md_mediation, c(
      list(d, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M", method = "ipw"), cfg)))
    ii <- missingmed:::.ipw_weights_info(md)
    cc <- ii$info$cc
    w <- ii$w[cc]
    fits <- list(
      m = suppressWarnings(stats::glm(M ~ X + C, data = d[cc, ], weights = w)),
      y = suppressWarnings(stats::glm(Y ~ X + M + C, data = d[cc, ], weights = w))
    )
    list(fits = fits, info = ii$info, md = md)
  }, error = function(e) list(error = conditionMessage(e)))
}

# 95% interval for a*b from the distribution of the product, given the 2x2
# covariance of (a, b). Returns NA endpoints (and pd = FALSE) when the block is not
# positive definite, so the replication is counted, not dropped.
ipw_interval <- function(a, b, S2) {
  pd <- is.finite(det(S2)) && all(is.finite(S2)) && min(eigen(S2, symmetric = TRUE, only.values = TRUE)$values) > 0
  if (!pd) return(c(lo = NA_real_, hi = NA_real_, pd = 0))
  ci <- tryCatch(RMediation::ci(RMediation::ProductNormal(mu = c(a, b), Sigma = S2),
    level = .95, type = "dop")$CI, error = function(e) c(NA_real_, NA_real_))
  c(lo = ci[1], hi = ci[2], pd = 1)
}

# Everything one replication reports: for each weight form, the arms
#   known_hc3   = today's behavior (medfit: HC3 sandwich per regression, cov(a, b) = 0),
#   known_hc0   = the same with HC0, so the effect of estimating the weights can be
#                 separated from the small-sample correction,
#   stacked_hc0 / stacked_hc1 / stacked_hc3 = .ipw_stacked_vcov() (full 2x2 block);
# plus, for the unstabilized joint form only, the control arm `model_se` (model-based
# covariance, documented as invalid under weighting). Truth is the stored population
# a*b of the complete-data regressions (smoke --write-defs). Diagnostics per form:
# effective sample size, the largest weight's share, the trimmed share.
one_ipw <- function(cell, seed, forms = ipw_forms) {
  d <- gen_ipw(cell$dgm, cell$n, cell$a, cell$b, cell$miss, cell$alpha, seed)
  tt <- ipw_truth_table()
  tt <- tt[tt$dgm == cell$dgm & tt$point == cell$point, ]
  stopifnot(nrow(tt) == 1L)
  truth <- tt$ab
  rows <- list()
  add <- function(form, arm, est, S2, n_cc, n_trim, diag, err = NA_character_) {
    iv <- if (is.null(S2)) c(lo = NA_real_, hi = NA_real_, pd = NA_real_) else ipw_interval(est[1], est[2], S2)
    rows[[length(rows) + 1L]] <<- data.frame(form = form, arm = arm, a = est[1], b = est[2],
      lo = iv[["lo"]], hi = iv[["hi"]], pd = iv[["pd"]], n_cc = n_cc, n_trim = n_trim,
      ess = diag[["ess"]], max_w_share = diag[["max_w_share"]], error = err, stringsAsFactors = FALSE)
  }
  stk <- c("stacked_hc0", "stacked_hc1", "stacked_hc3")
  for (nm in names(forms)) {
    f <- ipw_fit(d, forms[[nm]])
    if (!is.null(f$error)) {
      for (arm in c("known_hc3", "known_hc0", stk)) add(nm, arm, c(NA_real_, NA_real_), NULL, NA, NA, c(ess = NA, max_w_share = NA), f$error)
      next
    }
    est <- c(unname(stats::coef(f$fits$m)["X"]), unname(stats::coef(f$fits$y)["M"]))
    n_cc <- sum(f$info$cc); n_trim <- sum(f$info$trimmed)
    w <- unname(stats::weights(f$fits$m, "prior"))
    dg <- c(ess = sum(w)^2 / sum(w^2), max_w_share = max(w) / sum(w))
    v_hc3 <- c(sandwich::vcovHC(f$fits$m, type = "HC3")["X", "X"], sandwich::vcovHC(f$fits$y, type = "HC3")["M", "M"])
    i0 <- f$info; i0$blocks <- list()
    V0 <- missingmed:::.ipw_stacked_vcov(f$fits, i0, hc = "HC0")
    ia <- "m:X"; ib <- "y:M"
    add(nm, "known_hc3", est, diag(v_hc3), n_cc, n_trim, dg)
    add(nm, "known_hc0", est, V0[c(ia, ib), c(ia, ib)], n_cc, n_trim, dg)
    for (k in c("HC0", "HC1", "HC3")) {
      arm <- paste0("stacked_", tolower(k))
      V <- tryCatch(missingmed:::.ipw_stacked_vcov(f$fits, f$info, hc = k), error = function(e) conditionMessage(e))
      if (is.character(V)) add(nm, arm, est, NULL, n_cc, n_trim, dg, V)
      else add(nm, arm, est, V[c(ia, ib), c(ia, ib)], n_cc, n_trim, dg)
    }
    if (nm == "uj") {
      v_mod <- c(stats::vcov(f$fits$m)["X", "X"], stats::vcov(f$fits$y)["M", "M"])
      add(nm, "model_se", est, diag(v_mod), n_cc, n_trim, dg)
    }
  }
  out <- do.call(rbind, rows)
  out$truth <- truth; out$truth_a <- tt$a; out$truth_b <- tt$b
  out$cover <- with(out, lo <= truth & truth <= hi)
  out$reject0 <- with(out, lo > 0 | hi < 0)
  out$width <- out$hi - out$lo
  out$seed <- seed
  out
}
