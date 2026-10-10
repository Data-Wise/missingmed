# Stacked IPW variance (R/ipw_stack.R): step 1 and 2 of
# docs/specs/NOTE-ipw-weight-score-stacking-2026-10-09.md.

skip_if_not_installed("sandwich")

make_stack_data <- function(seed = 11, n = 400) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  miss <- plogis(-0.8 + 0.5 * d$X + 0.5 * d$C) > runif(n)
  d$M[miss] <- NA
  d
}

stack_md <- function(d, ...) {
  suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_stabilize = FALSE,
    weight_formula = ~ X + C, ...))
}

# Weighted fits with weights 1 / p(gamma), refitted by hand so gamma can move.
stack_fits <- function(d, gamma_shift = NULL) {
  dd <- d
  dd$.R <- as.integer(stats::complete.cases(d))
  mod <- stats::glm(.R ~ X + C, data = dd, family = stats::binomial())
  if (!is.null(gamma_shift)) mod$coefficients <- mod$coefficients + gamma_shift
  Z <- stats::model.matrix(~ X + C, dd)
  p <- as.numeric(stats::plogis(Z %*% mod$coefficients))
  cc <- dd$.R == 1
  w <- 1 / p[cc]
  dcc <- dd[cc, ]
  list(
    mod = mod,
    fits = list(
      m = stats::glm(M ~ X + C, data = dcc, weights = w),
      y = stats::glm(Y ~ X + M + C, data = dcc, weights = w)
    ),
    cc = cc
  )
}

test_that(".ipw_weights() keeps its value and .ipw_weights_info() adds the nuisance models", {
  d <- make_stack_data()
  md <- stack_md(d)
  w <- missingmed:::.ipw_weights(md)
  ii <- missingmed:::.ipw_weights_info(md)
  expect_identical(ii$w, w)
  expect_identical(ii$info$cc, stats::complete.cases(d))
  expect_length(ii$info$blocks, 1L)
  expect_identical(ii$info$blocks[[1]]$kind, "miss")
  expect_s3_class(ii$info$blocks[[1]]$model, "glm")
  expect_equal(1 / ii$info$blocks[[1]]$p[ii$info$cc], w[ii$info$cc])
  expect_false(any(ii$info$trimmed))
})

test_that(".ipw_weights_info() records the numerator, per-variable blocks and trimming", {
  d <- make_stack_data()
  d$Y[sample(nrow(d), 40)] <- NA
  md_s <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_stabilize = TRUE))
  # M and Y both incomplete: the default is sequential, a factor (and numerator) each
  expect_identical(vapply(missingmed:::.ipw_weights_info(md_s)$info$blocks,
    `[[`, "", "kind"), c("miss", "num", "miss", "num"))
  md_v <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_stabilize = TRUE,
    weight_formula = list(M = ~ X + C, Y = ~ X + C)))
  bl <- missingmed:::.ipw_weights_info(md_v)$info$blocks
  expect_identical(vapply(bl, `[[`, "", "kind"), c("miss", "num", "miss", "num"))
  expect_identical(vapply(bl, `[[`, "", "var"), c("M", "M", "Y", "Y"))
  md_t <- stack_md(d, weight_trim = 0.9)
  ii <- missingmed:::.ipw_weights_info(md_t)
  expect_true(any(ii$info$trimmed))
  expect_equal(max(ii$w, na.rm = TRUE), ii$info$cap)
  expect_gt(max(ii$info$w_untrimmed, na.rm = TRUE), ii$info$cap)
})

test_that("no missing values: weights 1 and no nuisance blocks", {
  d <- make_stack_data()
  d$M[is.na(d$M)] <- 0
  ii <- missingmed:::.ipw_weights_info(stack_md(d))
  expect_equal(ii$w, rep(1, nrow(d)))
  expect_length(ii$info$blocks, 0L)
})

test_that("with the weight-score term removed the stacked variance is the HC0 sandwich", {
  d <- make_stack_data()
  md <- stack_md(d)
  info <- missingmed:::.ipw_weights_info(md)$info
  sf <- stack_fits(d)
  # Known-weights limit: blocks dropped, so only H^{-1} (sum psi psi') H^{-1}.
  info0 <- info
  info0$blocks <- list()
  V <- missingmed:::.ipw_stacked_vcov(sf$fits, info0)
  km <- grep("^m:", rownames(V)); ky <- grep("^y:", rownames(V))
  expect_equal(unname(V[km, km]), unname(sandwich::vcovHC(sf$fits$m, type = "HC0")),
    tolerance = 1e-8)
  expect_equal(unname(V[ky, ky]), unname(sandwich::vcovHC(sf$fits$y, type = "HC0")),
    tolerance = 1e-8)
  # the cross block is H_m^{-1} (sum psi_m psi_y') H_y^{-1}, not medfit's zero
  expect_gt(max(abs(V[km, ky])), 0)
})

test_that("the weight-score correction has the sign and size of d theta_hat / d gamma", {
  d <- make_stack_data()
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  base <- stack_fits(d)
  coefs <- function(sf) unlist(lapply(sf$fits, stats::coef), use.names = FALSE)
  # numerical Jacobian of theta_hat in gamma: refit with gamma moved one coordinate at a time
  eps <- 1e-5
  g <- length(stats::coef(base$mod))
  Jnum <- vapply(seq_len(g), function(j) {
    sh <- rep(0, g); sh[j] <- eps
    (coefs(stack_fits(d, sh)) - coefs(stack_fits(d, -sh))) / (2 * eps)
  }, numeric(length(coefs(base))))
  # analytic: variance of (IF with the gamma term) minus (IF without) must match
  # J Var(gamma_hat) J' added to the known-weights variance plus the cross terms;
  # check the Jacobian itself against H^{-1} G through the exposed pieces.
  Z <- stats::model.matrix(base$mod)
  mu <- stats::fitted(base$mod)
  cc <- base$cc
  Jan <- do.call(rbind, lapply(base$fits, function(fit) {
    X <- stats::model.matrix(fit)
    ww <- stats::weights(fit, "working")
    psi <- X * (stats::residuals(fit, "working") * ww)
    G <- -crossprod(psi * (1 - mu[cc]), Z[cc, , drop = FALSE])
    solve(crossprod(X, X * ww)) %*% G
  }))
  expect_equal(unname(Jan), unname(Jnum), tolerance = 1e-5)
  # and the full stacked variance is the delta-method sum for the gamma part
  V <- missingmed:::.ipw_stacked_vcov(base$fits, info)
  V0 <- {
    i0 <- info; i0$blocks <- list()
    missingmed:::.ipw_stacked_vcov(base$fits, i0)
  }
  expect_false(isTRUE(all.equal(V, V0)))
  expect_true(isSymmetric(V, tol = 1e-10))
  expect_true(all(diag(V) > 0))
})

# Brute-force stacked M-estimation sandwich with numerical derivatives, built
# only from the fitted missingness models and the weight formula. The cap of a
# trimmed fit is held at its fitted value (the package treats it as a constant).
brute_stacked <- function(d, md) {
  ii <- missingmed:::.ipw_weights_info(md)
  info <- ii$info
  cc <- info$cc; N <- nrow(d)
  w <- ii$w
  fits <- list(
    m = stats::glm(M ~ X + C, data = d[cc, ], weights = w[cc]),
    y = stats::glm(Y ~ X + M + C, data = d[cc, ], weights = w[cc])
  )
  bl <- info$blocks
  Zs <- lapply(bl, function(b) stats::model.matrix(b$model))
  ys <- lapply(bl, function(b) b$model$y)
  ix <- lapply(bl, `[[`, "rows")   # the rows each model was fitted on (a sequential factor uses a subset)
  kinds <- vapply(bl, `[[`, "", "kind")
  gs <- vapply(Zs, ncol, 1L)
  Xm <- stats::model.matrix(fits$m); Xy <- stats::model.matrix(fits$y)
  Mc <- d$M[cc]; Yc <- d$Y[cc]
  km <- ncol(Xm); ky <- ncol(Xy); G <- sum(gs)
  cap <- info$cap
  rows <- function(par) {
    out <- matrix(0, N, G + km + ky)
    logw <- 0
    off <- 0L
    for (b in seq_along(bl)) {
      gam <- par[off + seq_len(gs[b])]
      pb <- as.numeric(stats::plogis(Zs[[b]] %*% gam))
      out[ix[[b]], off + seq_len(gs[b])] <- Zs[[b]] * (ys[[b]] - pb)
      lw <- numeric(N)
      lw[ix[[b]]] <- (if (kinds[b] == "num") 1 else -1) * log(pb)
      logw <- logw + lw
      off <- off + gs[b]
    }
    wc <- exp(logw)[cc]
    if (!is.na(cap)) wc <- pmin(wc, cap)
    tm <- par[G + seq_len(km)]; ty <- par[G + km + seq_len(ky)]
    out[cc, G + seq_len(km)] <- Xm * as.numeric(wc * (Mc - Xm %*% tm))
    out[cc, G + km + seq_len(ky)] <- Xy * as.numeric(wc * (Yc - Xy %*% ty))
    out
  }
  par_hat <- c(unlist(lapply(bl, function(b) stats::coef(b$model))),
    stats::coef(fits$m), stats::coef(fits$y))
  # the fits solve the stacked equations (checks that the weights were rebuilt right)
  stopifnot(max(abs(colSums(rows(par_hat)))) < 1e-6)
  eps <- 1e-6
  A <- vapply(seq_along(par_hat), function(j) {
    e <- rep(0, length(par_hat)); e[j] <- eps
    -(colSums(rows(par_hat + e)) - colSums(rows(par_hat - e))) / (2 * eps)
  }, numeric(length(par_hat)))
  Ainv <- solve(A)
  Vfull <- Ainv %*% crossprod(rows(par_hat)) %*% t(Ainv)
  idx <- G + seq_len(km + ky)
  list(brute = unname(Vfull[idx, idx]), fits = fits, info = info)
}

expect_stack_matches_brute <- function(d, md) {
  b <- brute_stacked(d, md)
  V <- missingmed:::.ipw_stacked_vcov(b$fits, b$info)
  expect_equal(unname(V), b$brute, tolerance = 1e-5)
  invisible(b)
}

test_that("the stacked variance equals a brute-force stacked M-estimation sandwich", {
  d <- make_stack_data(seed = 5, n = 300)
  expect_stack_matches_brute(d, stack_md(d))
})

test_that("stabilized weights (numerator model) match the brute-force sandwich", {
  d <- make_stack_data(seed = 6, n = 300)
  md <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_stabilize = TRUE,
    weight_formula = ~ X + C))
  b <- expect_stack_matches_brute(d, md)
  expect_identical(vapply(b$info$blocks, `[[`, "", "kind"), c("miss", "num"))
})

test_that("per-variable missingness models (stabilized or not) match the brute-force sandwich", {
  d <- make_stack_data(seed = 7, n = 300)
  d$Y[sample(nrow(d), 60)] <- NA
  for (stab in c(FALSE, TRUE)) {
    md <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
      treatment = "X", mediator = "M", method = "ipw", weight_stabilize = stab,
      weight_formula = list(M = ~ X + C, Y = ~ X + C)))
    b <- expect_stack_matches_brute(d, md)
    expect_length(b$info$blocks, if (stab) 4L else 2L)
  }
})

test_that("trimmed weights: the constant-cap variance matches the brute-force sandwich", {
  d <- make_stack_data(seed = 8, n = 300)
  md <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_stabilize = TRUE,
    weight_formula = ~ X + C, weight_trim = 0.9))
  b <- expect_stack_matches_brute(d, md)
  expect_true(any(b$info$trimmed))
  # trimming changes the variance relative to untrimmed weights
  md0 <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_stabilize = TRUE,
    weight_formula = ~ X + C))
  b0 <- brute_stacked(d, md0)
  expect_false(isTRUE(all.equal(b$brute, b0$brute)))
})

test_that(".ipw_stacked_vcov() refuses fits it cannot check", {
  d <- make_stack_data()
  sf <- stack_fits(d)
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  # weights that are not the estimated, capped IPW weights
  bad <- list(m = stats::glm(M ~ X + C, data = d[sf$cc, ]), y = sf$fits$y)
  expect_error(missingmed:::.ipw_stacked_vcov(bad, info), "weights in `info`")
  expect_error(missingmed:::.ipw_stacked_vcov(unname(sf$fits), info), "named list")
})

# --- HC variants (SPEC-ipw-stack-hc-gate-2026-10-09.md, plan T2) -------------------------

# Known answer: with the weight-score blocks removed the stacked variance is the
# per-regression sandwich, so HC3 / HC1 must equal sandwich::vcovHC to 1e-8.
test_that("HC3 and HC1 with the weight-score blocks removed equal sandwich::vcovHC", {
  d <- make_stack_data(seed = 12, n = 350)
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  sf <- stack_fits(d)
  i0 <- info; i0$blocks <- list()
  for (hc in c("HC3", "HC1", "HC0")) {
    V <- missingmed:::.ipw_stacked_vcov(sf$fits, i0, hc = hc)
    for (nm in names(sf$fits)) {
      ix <- grep(paste0("^", nm, ":"), rownames(V))
      expect_equal(unname(V[ix, ix]),
        unname(sandwich::vcovHC(sf$fits[[nm]], type = hc)), tolerance = 1e-8,
        label = paste(hc, nm))
    }
  }
})

test_that("the HC anchor can fail: the exponent and leverage errors are detectable", {
  d <- make_stack_data(seed = 12, n = 350)
  sf <- stack_fits(d)
  fit <- sf$fits$y
  X <- stats::model.matrix(fit)
  ww <- unname(stats::weights(fit, "working"))
  psi <- X * (unname(stats::residuals(fit, "working")) * ww)
  Hinv <- solve(crossprod(X, X * ww))
  target <- unname(sandwich::vcovHC(fit, type = "HC3"))
  vh <- function(fac) unname(crossprod((psi * fac) %*% Hinv))
  h <- unname(stats::hatvalues(fit))
  expect_equal(vh(1 / (1 - h)), target, tolerance = 1e-8)               # the right factor
  expect_gt(max(abs(vh(1 / (1 - h)^2) - target)), 1e-6 * max(abs(target)))  # squared: wrong
  # leverage of the unweighted regression is a different quantity: using it would also fail the anchor
  h_unw <- unname(stats::hatvalues(stats::glm(Y ~ X + M + C, data = d[sf$cc, ])))
  expect_gt(max(abs(vh(1 / (1 - h_unw)) - target)), 1e-6 * max(abs(target)))
})

test_that("the HC3 cross block between regressions is the product of their leverage-scaled scores", {
  d <- make_stack_data(seed = 13, n = 350)
  sf <- stack_fits(d)
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  i0 <- info; i0$blocks <- list()
  V <- missingmed:::.ipw_stacked_vcov(sf$fits, i0, hc = "HC3")
  um <- function(fit) {
    X <- stats::model.matrix(fit); ww <- unname(stats::weights(fit, "working"))
    psi <- X * (unname(stats::residuals(fit, "working")) * ww) / (1 - unname(stats::hatvalues(fit)))
    psi %*% solve(crossprod(X, X * ww))
  }
  expect_equal(unname(V[grep("^m:", rownames(V)), grep("^y:", colnames(V))]),
    unname(crossprod(um(sf$fits$m), um(sf$fits$y))), tolerance = 1e-8)
})

test_that("a leverage-one complete case is an error for HC3, not Inf", {
  d <- make_stack_data(seed = 14, n = 300)
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  cc <- info$cc
  dd <- d[cc, ]
  dd$g <- factor(ifelse(seq_len(nrow(dd)) == 1L, "solo", "rest"))   # one row owns a coefficient
  w <- missingmed:::.ipw_weights(stack_md(d))[cc]
  fits <- list(m = stats::glm(M ~ X + C + g, data = dd, weights = w),
    y = stats::glm(Y ~ X + M + C + g, data = dd, weights = w))
  i0 <- info; i0$blocks <- list()
  expect_error(missingmed:::.ipw_stacked_vcov(fits, i0, hc = "HC3"), "leverage")
  expect_no_error(missingmed:::.ipw_stacked_vcov(fits, i0, hc = "HC0"))
})

test_that("hc defaults to HC0 and rejects an unknown variant", {
  d <- make_stack_data(seed = 12, n = 300)
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  sf <- stack_fits(d)
  expect_identical(missingmed:::.ipw_stacked_vcov(sf$fits, info),
    missingmed:::.ipw_stacked_vcov(sf$fits, info, hc = "HC0"))
  expect_error(missingmed:::.ipw_stacked_vcov(sf$fits, info, hc = "HC2"), "should be one of")
})
