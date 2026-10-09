# Shared pieces of the missingness-model gate for IPW
# (SPEC-ipw-missingness-default-2026-10-09.md, plan item F7). Sourced by
# sim-ipw-mech-hopper.R (SLURM array), sim-ipw-mech-combine.R and
# sim-ipw-mech-smoke.R. Not part of the package build.
#
# The weights are computed here, not by the package: the sequential forms do not
# exist in R/ yet (that is what the gate decides). The joint and marginal weights
# are checked against the package's own on hopper (`smoke --package`). The point
# estimate and variance are the shipped path: weighted glm per regression, HC3
# sandwich per regression, cov(a, b) = 0.
Sys.setenv(SIM_NO_PKG = "1")
source("dev/sim-ipw-stack-lib.R")   # ipw_dgms, ipw_points, ipw_drivers, ipw_intercept, gen_ipw, ipw_interval, truth table

MECHS <- c("ind", "sim", "mono")
MECH_DGMS <- c("std", "aux", "auxm")
FORMS <- c("joint", "marginal", "seq", "seqrev", "true")
RHS <- c("X", "C", "Z")   # every driver of the missingness, so each factor is correctly specified

# Missingness mechanisms (spec section 5). `lin` is the missingness logit's linear part
# shared with the earlier gates; P(M missing) = plogis(alpha + lin).
#   ind : M and Y missing separately, each with P = plogis(alpha + lin)
#   sim : one draw drops M and Y together
#   mono: Y is missing whenever M is, and otherwise with P = plogis(alpha_y + lin);
#         M's share is half the nominal share, Y's is the nominal share
mech_alpha_y <- function(dgm, miss, alpha_m) {
  set.seed(20261009)
  v <- ipw_drivers(2e5); p <- ipw_dgms[[dgm]]
  lin <- p$s_x * v$X + p$s_c * v$C + p$s_z * v$Z
  pm <- plogis(alpha_m + lin)
  stats::uniroot(function(ay) mean(pm + (1 - pm) * plogis(ay + lin)) - miss, c(-15, 15), tol = 1e-12)$root
}

# The 162 cells, fixed order (cell index = row).
mech_cells <- function() {
  cells <- expand.grid(mech = MECHS, dgm = MECH_DGMS, n = c(200, 500, 5000), miss = c(.25, .40),
    point = c("P1", "P2", "P4"), stringsAsFactors = FALSE)
  cells <- cells[order(match(cells$mech, MECHS), match(cells$dgm, MECH_DGMS), cells$n, cells$miss,
    match(cells$point, ipw_points$point)), ]
  rownames(cells) <- NULL
  pt <- ipw_points[match(cells$point, ipw_points$point), c("a", "b")]
  rownames(pt) <- NULL
  share_m <- ifelse(cells$mech == "mono", cells$miss / 2, cells$miss)
  alpha <- unlist(Map(ipw_intercept, cells$dgm, share_m))
  alpha_y <- unlist(Map(function(m, d, ms, al) if (m == "mono") mech_alpha_y(d, ms, al) else NA_real_,
    cells$mech, cells$dgm, cells$miss, alpha))
  cbind(cells, pt, alpha = unname(alpha), alpha_y = unname(alpha_y))
}

# One incomplete dataset; attribute `p_cc` is the true P(complete | X, C, Z).
gen_mech <- function(cell, seed) {
  d <- gen_ipw(cell$dgm, cell$n, cell$a, cell$b, cell$miss, cell$alpha, seed, complete = TRUE)
  p <- ipw_dgms[[cell$dgm]]; n <- cell$n
  lin <- p$s_x * d$X + p$s_c * d$C + p$s_z * d$Z
  pm <- plogis(cell$alpha + lin)
  u1 <- stats::runif(n); u2 <- stats::runif(n)
  if (cell$mech == "ind") {
    mi <- u1 < pm; yi <- u2 < pm; p_cc <- (1 - pm)^2
  } else if (cell$mech == "sim") {
    mi <- yi <- u1 < pm; p_cc <- 1 - pm
  } else {
    py <- plogis(cell$alpha_y + lin)
    mi <- u1 < pm; yi <- mi | (u2 < py); p_cc <- (1 - pm) * (1 - py)
  }
  d$M[mi] <- NA; d$Y[yi] <- NA
  attr(d, "p_cc") <- p_cc
  d
}

# P(R = 1) predicted for every row from a logistic model fitted on `rows`. A response
# that is 1 on every fitted row (the second factor under simultaneous missingness) has
# probability 1: no model is fitted and the factor is flagged `degenerate`. A response
# that is 0 everywhere, or a fit that does not converge, is an error / flagged.
.fit_factor <- function(R, rhs, d, rows) {
  if (!any(R[rows])) stop("a missingness response is all zero on the fitted rows", call. = FALSE)
  if (all(R[rows])) return(list(p = rep(1, nrow(d)), degenerate = 1L, nonconv = 0L))
  dd <- d[rows, , drop = FALSE]; dd$.R <- as.integer(R[rows])
  m <- suppressWarnings(stats::glm(stats::reformulate(rhs, ".R"), data = dd, family = stats::binomial()))
  list(p = unname(stats::predict(m, d, type = "response")), degenerate = 0L, nonconv = as.integer(!m$converged))
}

# Weights for one form. Stabilized (numerator: the same factors on treatment only), as
# the shipped default. `form` "true" uses the DGM's own P(complete) and no numerator.
# Order of the sequential forms: ascending share of missing values, ties M then Y
# (spec section 6); "seqrev" is the reverse, a diagnostic.
mech_weights <- function(d, form) {
  n <- nrow(d)
  R <- list(M = !is.na(d$M), Y = !is.na(d$Y))
  cc <- R$M & R$Y
  deg <- 0L; nonconv <- 0L
  if (form == "true") return(list(w = ifelse(cc, 1 / attr(d, "p_cc"), NA_real_), cc = cc, degenerate = 0L, nonconv = 0L))
  num_den <- function(rhs) {
    if (form == "joint") {
      f <- .fit_factor(cc, rhs, d, rep(TRUE, n)); return(list(p = f$p, deg = f$degenerate, nc = f$nonconv))
    }
    share <- c(M = mean(!R$M), Y = mean(!R$Y))
    ord <- names(share)[order(share, c(1, 2))]
    if (form == "seqrev") ord <- rev(ord)
    p <- rep(1, n); dg <- 0L; nc <- 0L; earlier <- rep(TRUE, n)
    for (v in ord) {
      rows <- if (form == "marginal") rep(TRUE, n) else earlier
      f <- .fit_factor(R[[v]], rhs, d, rows)
      p <- p * f$p; dg <- dg + f$degenerate; nc <- nc + f$nonconv
      earlier <- earlier & R[[v]]
    }
    list(p = p, deg = dg, nc = nc)
  }
  den <- num_den(RHS); num <- num_den("X")
  w <- num$p / den$p
  w[!cc] <- NA_real_
  list(w = w, cc = cc, degenerate = den$deg, nonconv = den$nc + num$nc)
}

# Estimate and shipped-path interval from one weight vector.
mech_fit <- function(d, wi) {
  cc <- wi$cc; dd <- d[cc, ]; w <- wi$w[cc]
  fm <- suppressWarnings(stats::glm(M ~ X + C, data = dd, weights = w))
  fy <- suppressWarnings(stats::glm(Y ~ X + M + C, data = dd, weights = w))
  est <- c(unname(stats::coef(fm)["X"]), unname(stats::coef(fy)["M"]))
  v <- c(sandwich::vcovHC(fm, type = "HC3")["X", "X"], sandwich::vcovHC(fy, type = "HC3")["M", "M"])
  list(est = est, S2 = diag(v), n_cc = sum(cc), ess = sum(w)^2 / sum(w^2), max_w_share = max(w) / sum(w))
}

# Everything one replication reports: one row per weight form.
one_mech <- function(cell, seed, forms = FORMS) {
  d <- gen_mech(cell, seed)
  tt <- ipw_truth_table()
  tt <- tt[tt$dgm == cell$dgm & tt$point == cell$point, ]
  stopifnot(nrow(tt) == 1L)
  rows <- lapply(forms, function(fm) {
    r <- tryCatch({
      wi <- mech_weights(d, fm)
      f <- mech_fit(d, wi)
      iv <- ipw_interval(f$est[1], f$est[2], f$S2)
      data.frame(form = fm, a = f$est[1], b = f$est[2], lo = iv[["lo"]], hi = iv[["hi"]], pd = iv[["pd"]],
        n_cc = f$n_cc, ess = f$ess, max_w_share = f$max_w_share, degenerate = wi$degenerate,
        nonconv = wi$nonconv, error = NA_character_, stringsAsFactors = FALSE)
    }, error = function(e) data.frame(form = fm, a = NA_real_, b = NA_real_, lo = NA_real_, hi = NA_real_,
      pd = NA_real_, n_cc = NA_integer_, ess = NA_real_, max_w_share = NA_real_, degenerate = NA_integer_,
      nonconv = NA_integer_, error = conditionMessage(e), stringsAsFactors = FALSE))
    r
  })
  out <- do.call(rbind, rows)
  out$truth <- tt$ab; out$truth_a <- tt$a; out$truth_b <- tt$b
  out$cover <- with(out, lo <= truth & truth <= hi)
  out$reject0 <- with(out, lo > 0 | hi < 0)
  out$width <- out$hi - out$lo
  out$seed <- seed
  out
}
