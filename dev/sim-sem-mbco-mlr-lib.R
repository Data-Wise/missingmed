# Shared pieces of the MLR simulation gate for MBCO with engine = "lavaan"
# (SPEC-sem-mbco-2026-10-08.md, section 5, T8b). Sourced by
# sim-sem-mbco-mlr-hopper.R (SLURM array). Not part of the package build.
#
# The cells are the ML gate's (dev/sim-sem-mbco-lib.R: DGP x n x missingness x
# null) with non-normal structural and measurement errors, scaled to unit
# variance: skewed = chi-square(4), heavy = t(5). X and C stay normal.
# The statistic is the one fixed in section 5: D4 on the naive LRTs divided by
# the mean per-imputation Satorra-Bentler (2001) scaling correction of the
# winning branch (ariv = "fixed"); this is NOT lavaan.mi's procedure (harmonic
# mean of the per-model factors, chi-square reference), see spec section 12.
# Also recorded, as comparators: the naive D4 p-value (what the scaling is for)
# and D2 on the scaled per-imputation statistics (own implementation of Li et
# al. 1991, secondary only). The pooling refuses MLR publicly, so this harness
# sets options(missingmed.internal_mlr = TRUE).
source("dev/sim-sem-mbco-lib.R") # nulls, and the package (load_all or installed)
options(missingmed.internal_mlr = TRUE) # lifts the public MLR refusal for this harness only

err <- function(dist, n) {
  switch(dist,
    skewed = (stats::rchisq(n, 4) - 4) / sqrt(8),
    heavy = stats::rt(n, 5) / sqrt(5 / 3),
    stop("dist must be 'skewed' or 'heavy'")
  )
}

# The ML gate's generator with err() in place of rnorm() for every error term.
gen_nn <- function(dist, dgp, n, a, b, miss, seed) {
  set.seed(seed)
  X <- rnorm(n)
  if (dgp == "observed") {
    C <- rnorm(n)
    M <- a * X + .3 * C + err(dist, n)
    Y <- b * M + .2 * X + .3 * C + err(dist, n)
    d <- data.frame(X, M, Y, C)
    d$M[runif(n) < plogis(qlogis(miss) + .6 * d$C + .5 * d$Y)] <- NA
  } else {
    L <- a * X + err(dist, n)
    d <- data.frame(X,
      m1 = L + .6 * err(dist, n), m2 = .8 * L + .6 * err(dist, n), m3 = .7 * L + .6 * err(dist, n)
    )
    d$Y <- b * L + .2 * X + err(dist, n)
    for (v in c("m1", "m2", "m3")) d[[v]][runif(n) < plogis(qlogis(miss) + .5 * d$Y + .3 * d$X)] <- NA
  }
  d
}

# D2 of the scaled per-imputation statistics T_k (Li et al. 1991, on sqrt(T_k)),
# each imputation on its OWN winning branch. Secondary comparator only.
d2_p <- function(T_k, k) {
  K <- length(T_k)
  r2 <- (1 + 1 / K) * stats::var(sqrt(T_k))
  D2 <- max(0, (mean(T_k) / k - (K + 1) / (K - 1) * r2) / (1 + r2))
  nu2 <- k^(-3 / K) * (K - 1) * (1 + 1 / r2)^2
  stats::pf(D2, k, nu2, lower.tail = FALSE)
}

# One replication. Returns a one-row data.frame (schema `v` = 2).
# The provider is run once per dataset and its outputs are logged; the logged
# outputs are then pooled twice, with no extra model fits:
#   pass 1, corrections stripped: the NAIVE D4 (the existing ML MBCO statistic),
#           available whenever the fits themselves succeeded;
#   pass 2, replayed with the corrections: the scaled D4 and D2, which can REFUSE
#           (a used correction that is not positive).
# So the naive comparator never depends on scaling succeeding (Codex review,
# 2026-10-10). Failure kinds: p_d4n NA = a fit failed (all p-values NA);
# p_d4n present with p_d4s NA = the scaling refused. `err` holds the message.
one_mlr <- function(dist, dgp, n, a, b, miss, seed) {
  d <- gen_nn(dist, dgp, n, a, b, miss, seed)
  imp <- suppressWarnings(mice::mice(d, m = 20, maxit = 5, method = "norm", printFlag = FALSE, seed = seed))
  il <- mice::complete(imp, "all")
  model <- if (dgp == "observed") "M ~ X + C\nY ~ M + X + C" else "Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ Ml + X"
  med <- if (dgp == "observed") "M" else "Ml"
  prov <- missingmed:::.mm_lav_provider(model, "X", med, "Y", list(estimator = "MLR"))
  log <- list()
  strip <- function(l) {
    out <- l[setdiff(names(l), c("cd_a", "cd_b"))]
    attr(out, "improper") <- attr(l, "improper")
    out
  }
  logged <- function(dd) {
    l <- prov(dd)
    log[[length(log) + 1L]] <<- l
    strip(l)
  }
  row <- data.frame(p_d4s = NA_real_, p_d4n = NA_real_, p_d2 = NA_real_, cd = NA_real_, k = NA_real_,
    r4 = NA_real_, err = NA_character_, v = 2L)
  naive <- tryCatch(suppressWarnings(missingmed:::.mm_d4_pool(unname(il), logged, "fixed")),
    error = function(e) conditionMessage(e))
  if (is.character(naive)) {
    row$err <- naive
    return(row)
  }
  row$p_d4n <- unname(naive["p"])
  row$k <- naive@k
  row$r4 <- unname(naive["r4"])
  i <- 0L
  replay <- function(dd) {
    i <<- i + 1L
    log[[i]]
  }
  r <- tryCatch(suppressWarnings(missingmed:::.mm_d4_pool(unname(il), replay, "fixed")),
    error = function(e) conditionMessage(e))
  if (is.character(r)) {
    row$err <- r
    return(row)
  }
  K <- length(il)
  T_k <- vapply(log[seq_len(K)], function(l) {
    key <- if (l[["a"]] >= l[["b"]]) "a" else "b"
    2 * (l[["full"]] - l[[key]]) / l[[paste0("cd_", key)]]
  }, numeric(1))
  row$p_d4s <- unname(r["p"])
  row$p_d2 <- tryCatch(d2_p(T_k, r@k), error = function(e) NA_real_)
  row$cd <- r@scaling
  row
}

# 2 distributions x 2 DGPs x n x missingness x 5 nulls = 80 cells at the spec's grid.
mlr_cells <- function(ns = c(200L, 500L), miss = c(0.25, 0.40)) {
  expand.grid(dist = c("skewed", "heavy"), dgp = c("observed", "latent"), n = ns, miss = miss,
    null = seq_along(nulls), stringsAsFactors = FALSE)
}
