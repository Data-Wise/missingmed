# The lavaan log-likelihood provider for D4-stacked MBCO
# (SPEC-sem-mbco-2026-10-08.md, T2: observed-variable models).

skip_if_not_installed("mice")

make_imps <- function(K = 4, n = 120, a = 0.6, b = 0.15, seed = 300) {
  lapply(seq_len(K), function(k) {
    set.seed(seed + k)
    X <- rnorm(n)
    C <- rnorm(n)
    M <- a * X + 0.3 * C + rnorm(n)
    data.frame(X = X, M = M, Y = b * M + 0.2 * X + 0.3 * C + rnorm(n), C = C)
  })
}

MOD <- "M ~ X + C\nY ~ M + X + C"
prov <- function(model = MOD, fit_args = list()) {
  missingmed:::.mm_lav_provider(model, "X", "M", "Y", fit_args)
}
glm_d4 <- function(imps, ariv) {
  mbco_d4(imps, Y ~ M + X + C, M ~ X + C, treatment = "X", mediator = "M", ariv = ariv)
}
pool <- function(imps, ariv, provider = prov()) missingmed:::.mm_d4_pool(imps, provider, ariv)

test_that("lavaan equals the glm engine on an observed model, both branches, both ariv", {
  for (cfg in list(c(a = 0.6, b = 0.15), c(a = 0.15, b = 0.6))) { # b wins, then a wins
    imps <- make_imps(a = cfg[["a"]], b = cfg[["b"]])
    for (ariv in c("fixed", "own")) {
      got <- pool(imps, ariv)
      ref <- glm_d4(imps, ariv)
      expect_equal(as.vector(got), as.vector(ref), tolerance = 1e-8)
      # The a/b labels cancel in D4 and p; the diagnostics do not.
      expect_identical(got@stacked_branch, ref@stacked_branch)
      expect_equal(got@p_branch_a, ref@p_branch_a)
      expect_equal(got@k, ref@k)
    }
  }
  expect_identical(pool(make_imps(a = 0.6, b = 0.15), "fixed")@stacked_branch, "b")
  expect_identical(pool(make_imps(a = 0.15, b = 0.6), "fixed")@stacked_branch, "a")
})

test_that("each null equals the 0* syntax oracle (catches swapped rows)", {
  d <- make_imps(K = 1)[[1]]
  t3 <- prov()(d)
  ll <- function(syn) as.numeric(lavaan::fitMeasures(suppressWarnings(lavaan::sem(syn, data = d)), "logl"))
  expect_equal(t3[["full"]], ll(MOD), tolerance = 1e-9)
  expect_equal(t3[["a"]], ll("M ~ 0*X + C\nY ~ M + X + C"), tolerance = 1e-9)
  expect_equal(t3[["b"]], ll("M ~ X + C\nY ~ 0*M + X + C"), tolerance = 1e-9)
  expect_gt(abs(t3[["a"]] - t3[["b"]]), 1) # the two nulls differ, so a swap shows
  expect_equal(unname(t3[c("k_a", "k_b")]), c(1, 1))
})

test_that("K identical copies reproduce the single-dataset LRT with r4 = 0", {
  d <- make_imps(K = 1)[[1]]
  r <- pool(list(d, d, d), "fixed")
  full <- suppressWarnings(lavaan::sem(MOD, data = d))
  win <- if (r@stacked_branch == "a") "M ~ 0*X + C\nY ~ M + X + C" else "M ~ X + C\nY ~ 0*M + X + C"
  lrt <- lavaan::lavTestLRT(full, suppressWarnings(lavaan::sem(win, data = d)))
  expect_equal(unname(r["D4"]), lrt[["Chisq diff"]][2], tolerance = 1e-6)
  expect_equal(unname(r["r4"]), 0)
})

test_that("a model without exactly one a path or one b path is refused before pooling", {
  imps <- make_imps()
  expect_error(pool(imps, "fixed", prov("M ~ C\nY ~ M + X + C")), "exactly one `M ~ X`")
  expect_error(pool(imps, "fixed", prov("M ~ X + C\nY ~ X + C")), "exactly one `Y ~ M`")
})

test_that("a non-converged lavaan fit refuses, naming dataset and fit", {
  imps <- make_imps()
  p <- prov(fit_args = list(control = list(iter.max = 1)))
  expect_error(pool(imps, "fixed", p), "imputation 1.*(full|a = 0|b = 0) lavaan model did not converge")
})

test_that("an explicit ML estimator in fit_args gives the same result", {
  imps <- make_imps()
  # Same statistic whether or not the (default) estimator is spelled out.
  expect_equal(
    as.vector(pool(imps, "fixed", prov(fit_args = list(estimator = "ML")))),
    as.vector(pool(imps, "fixed")), tolerance = 1e-10
  )
})
