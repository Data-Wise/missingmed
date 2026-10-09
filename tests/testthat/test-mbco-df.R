# The D4 denominator df is Chan & Meng (2022; arXiv:1711.08822) eq. 2.15, nu = k (K - 1) (1 + 1 / r4)^2,
# the one `mitml::testModels(method = "D4")` uses, not the Li et al. (1991) df
# (docs/specs/NOTE-d4-denominator-vs-mitml-2026-10-09.md).

test_that("nu is k (K - 1) (1 + 1 / r4)^2, for small and large k (K - 1)", {
  for (cfg in list(c(K = 5, k = 1), c(K = 20, k = 1), c(K = 20, k = 2), c(K = 3, k = 1), c(K = 10, k = 4))) {
    K <- cfg[["K"]]; k <- cfg[["k"]]
    set.seed(K * 10 + k)
    d_k <- stats::rchisq(K, k, ncp = 3) + 1
    d_S <- mean(d_k) - 0.4 # a positive gap, so r4 > 0
    out <- missingmed:::.mm_d4_from_stats(d_k, d_S, k = k)
    expect_equal(unname(out[["nu"]]), k * (K - 1) * (1 + 1 / out[["r4"]])^2, tolerance = 1e-12)
    expect_equal(unname(out[["p"]]),
      stats::pf(out[["D4"]], k, out[["nu"]], lower.tail = FALSE), tolerance = 1e-12)
  }
})

test_that("nu is Inf when r4 is 0 (no between-imputation variance)", {
  out <- missingmed:::.mm_d4_from_stats(c(4, 4, 4, 4), 4, k = 1)
  expect_equal(unname(out[["r4"]]), 0)
  expect_identical(unname(out[["nu"]]), Inf)
})

test_that("D4, r4, nu and p equal mitml::testModels(method = 'D4')", {
  skip_if_not_installed("mitml")
  skip_if_not_installed("mice")
  set.seed(21)
  n <- 300
  C <- rnorm(n); X <- rbinom(n, 1, .5)
  M <- .5 * X + .3 * C + rnorm(n)
  Y <- .25 * M + .2 * X + .3 * C + rnorm(n)
  d <- data.frame(X, M, Y, C)
  d$M[runif(n) < plogis(-.7 + .5 * C + .5 * Y)] <- NA
  K <- 20
  imp <- suppressWarnings(mice::mice(d, m = K, maxit = 5, method = "norm", printFlag = FALSE, seed = 3))
  il <- mice::complete(imp, "all")
  ll <- function(f, dd) as.numeric(stats::logLik(do.call(stats::glm, list(formula = f, data = dd))))
  for (cfg in list(list(Y ~ M + X + C, Y ~ X + C, 1), list(Y ~ M + X + C, Y ~ C, 2))) {
    f1 <- cfg[[1]]; f0 <- cfg[[2]]; k <- cfg[[3]]
    d_k <- vapply(il, function(dd) 2 * (ll(f1, dd) - ll(f0, dd)), 0)
    st <- do.call(rbind, il)
    d_S <- 2 * (ll(f1, st) - ll(f0, st)) / K
    mine <- missingmed:::.mm_d4_from_stats(d_k, d_S, k = k)
    fit <- function(f) structure(lapply(il, function(dd) do.call(stats::glm, list(formula = f, data = dd))),
      class = "mitml.result")
    mt <- suppressWarnings(mitml::testModels(fit(f1), fit(f0), method = "D4", data = il))$test
    expect_equal(unname(mine[["D4"]]), unname(mt[1, "F.value"]), tolerance = 1e-8)
    expect_equal(unname(mine[["r4"]]), unname(mt[1, "RIV"]), tolerance = 1e-8)
    expect_equal(unname(mine[["nu"]]), unname(mt[1, "df2"]), tolerance = 1e-8)
    expect_equal(unname(mine[["p"]]), unname(mt[1, "P(>F)"]), tolerance = 1e-8)
  }
})
