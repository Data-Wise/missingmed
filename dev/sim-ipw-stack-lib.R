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
# slopes of the missingness logit on X, C and Z. Missingness of M and Y share the
# slopes and the intercept, and are independent given the drivers.
ipw_dgms <- list(
  std = list(zm = 0, zy = 0, s_x = .5, s_c = .5, s_z = 0),
  aux = list(zm = 0, zy = .7, s_x = 0, s_c = 0, s_z = 1),
  auxm = list(zm = .7, zy = .7, s_x = 0, s_c = 0, s_z = 1)
)

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

# The 48 cells, in a fixed order (cell index = row).
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
  d$M[runif(n) < plogis(lin)] <- NA
  d$Y[runif(n) < plogis(lin)] <- NA
  d
}

# Complete-data population (a, b): the quantities IPW targets.
ipw_truth <- function(cell, N = 2e6, b_correct = TRUE) {
  d <- gen_ipw(cell$dgm, N, cell$a, cell$b, cell$miss, cell$alpha, seed = 777,
    b_correct = b_correct, complete = TRUE)
  c(a = unname(stats::coef(stats::lm(M ~ X + C, d))["X"]),
    b = unname(stats::coef(stats::lm(Y ~ X + M + C, d))["M"]))
}
