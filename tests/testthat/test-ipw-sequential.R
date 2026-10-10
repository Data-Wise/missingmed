# The sequential (chain-rule) missingness model of method = "ipw":
# docs/specs/SPEC-ipw-missingness-default-2026-10-09.md sections 6 and 11.
#   P(all observed | Z) = P(V1 obs | Z) * P(V2 obs | V1 obs, Z) * ...
# with each factor fitted on the rows where the earlier variables are observed.

skip_if_not_installed("medfit")

# M and Y missing for their own reasons ("ind") or together ("sim"). M is the
# less-missing variable, so the default order is M then Y, which is not the order
# of the model variables (Y, X, M, C).
seq_data <- function(n = 900, mech = c("ind", "sim"), seed = 3) {
  mech <- match.arg(mech)
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  pm <- plogis(qlogis(0.25) + 0.5 * X + 0.5 * C)
  py <- plogis(qlogis(0.40) + 0.5 * X + 0.5 * C)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  if (mech == "ind") {
    d$M[runif(n) < pm] <- NA
    d$Y[runif(n) < py] <- NA
  } else {
    r <- runif(n) < pm
    d$M[r] <- NA
    d$Y[r] <- NA
  }
  d
}

seq_md <- function(d, stabilize = FALSE, ...) {
  suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw",
    weight_stabilize = stabilize, ...))
}

# The chain rule fitted by hand, in the stated order, predictors X and C.
by_hand <- function(d, order, stabilize = FALSE, marginal = FALSE) {
  n <- nrow(d)
  p <- rep(1, n)
  pn <- rep(1, n)
  earlier <- rep(TRUE, n)
  for (v in order) {
    dd <- d
    dd$R <- as.integer(!is.na(d[[v]]))
    rows <- if (marginal) rep(TRUE, n) else earlier
    p <- p * stats::predict(stats::glm(R ~ X + C, binomial(), dd[rows, ]), dd, type = "response")
    pn <- pn * stats::predict(stats::glm(R ~ X, binomial(), dd[rows, ]), dd, type = "response")
    earlier <- earlier & dd$R == 1
  }
  w <- if (stabilize) pn / p else 1 / p
  w[!stats::complete.cases(d)] <- NA_real_
  unname(w)
}

test_that("the default weights are the chain rule, least-missing variable first", {
  d <- seq_data()
  expect_lt(mean(is.na(d$M)), mean(is.na(d$Y)))
  for (stab in c(FALSE, TRUE)) {
    w <- missingmed:::.ipw_weights(seq_md(d, stab))
    expect_equal(w, by_hand(d, c("M", "Y"), stab), tolerance = 1e-8)
    # the planted defect: the order changes the weights, so a wrong order is detectable
    expect_gt(max(abs(w - by_hand(d, c("Y", "M"), stab)), na.rm = TRUE), 1e-3)
  }
})

test_that("the default order is recorded in info and is not the order of the formula", {
  ii <- missingmed:::.ipw_weights_info(seq_md(seq_data(), TRUE))$info
  expect_identical(ii$order, c("M", "Y"))
  expect_true(ii$sequential)
  expect_identical(vapply(ii$blocks, `[[`, "", "var"), c("M", "M", "Y", "Y"))
  expect_identical(vapply(ii$blocks, `[[`, "", "kind"), c("miss", "num", "miss", "num"))
  # the second factor is fitted on the rows where M is observed, not on all rows
  by <- ii$blocks[[3]]
  expect_identical(by$rows, which(!is.na(seq_data()$M)))
})

test_that("with one incomplete variable the default is the model it always was", {
  d <- seq_data()
  d$Y[is.na(d$Y)] <- 0   # Y complete: only M is incomplete
  w_def <- missingmed:::.ipw_weights(seq_md(d, TRUE))
  w_joint <- missingmed:::.ipw_weights(seq_md(d, TRUE, weight_formula = ~ X + C + Y))
  expect_equal(w_def, w_joint, tolerance = 1e-10)
})

test_that("under simultaneous missingness the default equals the joint model, and the marginal product does not", {
  d <- seq_data(mech = "sim")
  md <- seq_md(d)
  ii <- missingmed:::.ipw_weights_info(md)
  w_joint <- missingmed:::.ipw_weights(seq_md(d, weight_formula = ~ X + C))
  expect_equal(ii$w, w_joint, tolerance = 1e-8)
  # the second factor is 1 on every fitted row: no model, recorded as degenerate
  expect_length(ii$info$degenerate, 1L)
  expect_length(ii$info$blocks, 1L)
  expect_gt(max(abs(by_hand(d, c("M", "Y"), marginal = TRUE) - ii$w), na.rm = TRUE), 0.05)
})

test_that("a named list is the sequence in list order, each entry conditional on the earlier ones", {
  d <- seq_data()
  w_my <- missingmed:::.ipw_weights(seq_md(d, TRUE, weight_formula = list(M = ~ X + C, Y = ~ X + C)))
  w_ym <- missingmed:::.ipw_weights(seq_md(d, TRUE, weight_formula = list(Y = ~ X + C, M = ~ X + C)))
  expect_equal(w_my, by_hand(d, c("M", "Y"), TRUE), tolerance = 1e-8)
  expect_equal(w_ym, by_hand(d, c("Y", "M"), TRUE), tolerance = 1e-8)
  expect_gt(max(abs(w_my - w_ym), na.rm = TRUE), 1e-3)
  # an entry for a complete variable adds nothing (it is observed everywhere)
  w_x <- missingmed:::.ipw_weights(seq_md(d, TRUE, weight_formula = list(M = ~ X + C, Y = ~ X + C, X = ~ C)))
  expect_equal(w_x, w_my, tolerance = 1e-10)
})

test_that("at n = 2e4 under simultaneous missingness the default recovers the true weights and the marginal product does not", {
  n <- 20000
  set.seed(42)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  pm <- plogis(qlogis(0.4) + 0.5 * X + 0.5 * C)
  r <- runif(n) < pm
  d <- data.frame(X = X, M = replace(M, r, NA), Y = replace(Y, r, NA), C = C)
  w_true <- 1 / (1 - pm)
  w <- missingmed:::.ipw_weights(seq_md(d))
  cc <- !r
  expect_lt(abs(stats::median(w[cc] / w_true[cc]) - 1), 0.02)
  w_marg <- by_hand(d, c("M", "Y"), marginal = TRUE)
  expect_gt(stats::median(w_marg[cc] / w_true[cc]), 1.3)
})

test_that("an incomplete treatment is one more factor and needs no numerator of its own", {
  d <- seq_data()
  d$X[1:40] <- NA
  ii <- missingmed:::.ipw_weights_info(seq_md(d, TRUE))$info
  expect_identical(ii$order[1], "X")   # the least-missing variable comes first
  # X's factor has a denominator model but no numerator (its indicator is constant
  # where X is observed); every other factor has both
  kinds <- paste(vapply(ii$blocks, `[[`, "", "var"), vapply(ii$blocks, `[[`, "", "kind"))
  expect_true("X miss" %in% kinds)
  expect_false("X num" %in% kinds)
  expect_true(all(c("M miss", "M num", "Y miss", "Y num") %in% kinds))
  w <- missingmed:::.ipw_weights(seq_md(d, TRUE))
  cc <- stats::complete.cases(d)
  expect_identical(is.na(w), !cc)
  expect_true(all(w[cc] > 0 & is.finite(w[cc])))
})

test_that("the stacked variance runs on the default sequential blocks", {
  d <- seq_data(n = 500)
  md <- seq_md(d, TRUE)
  ii <- missingmed:::.ipw_weights_info(md)
  cc <- ii$info$cc
  w <- ii$w[cc]
  fits <- list(
    m = stats::glm(M ~ X + C, data = d[cc, ], weights = w),
    y = stats::glm(Y ~ X + M + C, data = d[cc, ], weights = w)
  )
  V <- missingmed:::.ipw_stacked_vcov(fits, ii$info)
  expect_true(isSymmetric(V, tol = 1e-10))
  expect_true(all(diag(V) > 0))
})
