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
  expect_identical(vapply(missingmed:::.ipw_weights_info(md_s)$info$blocks,
    `[[`, "", "kind"), c("miss", "num"))
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

test_that("the stacked variance equals a brute-force stacked M-estimation sandwich", {
  d <- make_stack_data(seed = 5, n = 300)
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  sf <- stack_fits(d)
  cc <- sf$cc; N <- nrow(d)
  Z <- stats::model.matrix(~ X + C, d)
  Xm <- stats::model.matrix(M ~ X + C, d[cc, ])
  Xy <- stats::model.matrix(Y ~ X + M + C, d[cc, ])
  Mc <- d$M[cc]; Yc <- d$Y[cc]; R <- as.numeric(cc)
  g <- ncol(Z); km <- ncol(Xm); ky <- ncol(Xy)
  # per-row contributions to the stacked estimating equations, N x (g + km + ky)
  rows <- function(par) {
    gam <- par[seq_len(g)]; tm <- par[g + seq_len(km)]; ty <- par[g + km + seq_len(ky)]
    p <- as.numeric(stats::plogis(Z %*% gam))
    out <- matrix(0, N, g + km + ky)
    out[, seq_len(g)] <- Z * (R - p)
    w <- 1 / p[cc]
    out[cc, g + seq_len(km)] <- Xm * as.numeric(w * (Mc - Xm %*% tm))
    out[cc, g + km + seq_len(ky)] <- Xy * as.numeric(w * (Yc - Xy %*% ty))
    out
  }
  par_hat <- c(stats::coef(sf$mod), stats::coef(sf$fits$m), stats::coef(sf$fits$y))
  expect_lt(max(abs(colSums(rows(par_hat)))), 1e-6)   # the fits solve the stacked equations
  eps <- 1e-6
  A <- vapply(seq_along(par_hat), function(j) {
    e <- rep(0, length(par_hat)); e[j] <- eps
    -(colSums(rows(par_hat + e)) - colSums(rows(par_hat - e))) / (2 * eps)
  }, numeric(length(par_hat)))
  U <- rows(par_hat)
  Ainv <- solve(A)
  Vfull <- Ainv %*% crossprod(U) %*% t(Ainv)
  idx <- g + seq_len(km + ky)
  V <- missingmed:::.ipw_stacked_vcov(sf$fits, info)
  expect_equal(unname(V), unname(Vfull[idx, idx]), tolerance = 1e-5)
})

test_that(".ipw_stacked_vcov() refuses what it does not implement or cannot check", {
  d <- make_stack_data()
  sf <- stack_fits(d)
  md_s <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_stabilize = TRUE))
  expect_error(missingmed:::.ipw_stacked_vcov(sf$fits,
    missingmed:::.ipw_weights_info(md_s)$info), "unstabilized")
  info <- missingmed:::.ipw_weights_info(stack_md(d))$info
  # weights that are not 1 / p from the missingness model
  bad <- list(m = stats::glm(M ~ X + C, data = d[sf$cc, ]),
    y = sf$fits$y)
  expect_error(missingmed:::.ipw_stacked_vcov(bad, info), "1 / p")
  expect_error(missingmed:::.ipw_stacked_vcov(unname(sf$fits), info), "named list")
})
