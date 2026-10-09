# The log-likelihood provider seam of D4-stacked MBCO (SPEC-sem-mbco, S8).
#
# .mm_d4_pool() is estimator-free: it needs, per dataset, the named numeric
# c(full, a, b, k_a, k_b). These tests drive it with a provider that does not
# use the glm code path at all, so they fail if the pooling secretly depends on
# it. The lavaan provider (SPEC-sem-mbco T2) plugs into the same seam.

skip_if_not_installed("mice")

make_imps <- function(K = 4, n = 120, a = 0.6, b = 0.15) {
  lapply(seq_len(K), function(k) {
    set.seed(300 + k)
    X <- rnorm(n)
    C <- rnorm(n)
    M <- a * X + 0.3 * C + rnorm(n)
    Y <- b * M + 0.2 * X + 0.3 * C + rnorm(n)
    data.frame(X = X, M = M, Y = Y, C = C, tag = k)
  })
}

# An independent Gaussian provider: lm() log-likelihoods, k = 1 per path.
lm_provider <- function(swap = FALSE) {
  ll <- function(f, d) as.numeric(stats::logLik(stats::lm(f, data = d)))
  function(d) {
    full <- ll(M ~ X + C, d) + ll(Y ~ M + X + C, d)
    a0 <- ll(M ~ C, d) + ll(Y ~ M + X + C, d)
    b0 <- ll(M ~ X + C, d) + ll(Y ~ X + C, d)
    if (swap) c(full = full, a = b0, b = a0, k_a = 1, k_b = 1) else
      c(full = full, a = a0, b = b0, k_a = 1, k_b = 1)
  }
}

glm_d4 <- function(imps, ariv) {
  mbco_d4(imps, Y ~ M + X + C, M ~ X + C,
    treatment = "X", mediator = "M", ariv = ariv
  )
}

test_that("pooling with an independent provider equals the glm engine", {
  imps <- make_imps()
  for (ariv in c("fixed", "own")) {
    got <- missingmed:::.mm_d4_pool(imps, lm_provider(), ariv)
    ref <- glm_d4(imps, ariv)
    expect_equal(as.vector(got), as.vector(ref), tolerance = 1e-10)
    expect_identical(got@stacked_branch, ref@stacked_branch)
    expect_equal(got@k, ref@k)
  }
})

test_that("swapped a and b results are caught by the branch diagnostics only", {
  # The branch-union statistic max(ll_a, ll_b) is symmetric in a and b, so with
  # k = 1 on both paths D4 and p cannot tell a swap. The diagnostics can.
  imps <- make_imps()
  swapped <- missingmed:::.mm_d4_pool(imps, lm_provider(swap = TRUE), "fixed")
  ref <- glm_d4(imps, "fixed")
  expect_equal(as.vector(swapped), as.vector(ref), tolerance = 1e-10)
  expect_false(identical(swapped@stacked_branch, ref@stacked_branch))
  expect_equal(swapped@p_branch_a, 1 - ref@p_branch_a)
})

test_that("a provider error names the dataset it failed on", {
  imps <- make_imps()
  bad <- function(d) {
    if (identical(unique(d$tag), 3L)) stop("provider says no", call. = FALSE)
    lm_provider()(d)
  }
  expect_error(
    missingmed:::.mm_d4_pool(imps, bad, "fixed"),
    "Fitting the MBCO models failed in imputation 3: provider says no"
  )
  stacked_bad <- function(d) {
    if (length(unique(d$tag)) > 1L) stop("stack fails", call. = FALSE)
    lm_provider()(d)
  }
  expect_error(
    missingmed:::.mm_d4_pool(imps, stacked_bad, "fixed"),
    "failed in the stacked data: stack fails"
  )
})

test_that(".mm_fit_T_k takes k from the winning branch, ties to a", {
  f <- function(a, b) c(full = 0, a = a, b = b, k_a = 1, k_b = 3)
  expect_equal(unname(missingmed:::.mm_fit_T_k(f(-2, -5))["k"]), 1) # a wins
  expect_equal(unname(missingmed:::.mm_fit_T_k(f(-5, -2))["k"]), 3) # b wins
  expect_equal(unname(missingmed:::.mm_fit_T_k(f(-4, -4))["k"]), 1) # tie -> a
  expect_equal(unname(missingmed:::.mm_fit_T_k(f(-2, -5))["T"]), 4)
})

test_that("fewer than two datasets is refused before any provider call", {
  called <- FALSE
  p <- function(d) {
    called <<- TRUE
    lm_provider()(d)
  }
  expect_error(missingmed:::.mm_d4_pool(make_imps(K = 1), p, "fixed"), "at least 2 imputations")
  expect_false(called)
})
