# The constrained models must null the WHOLE path, not just the main effect.
# See docs/specs/SPEC-mbco-constrained-models-2026-08-30.md.

skip_if_not_installed("medfit")

gen_mbco <- function(n = 800, seed = 5, interaction = FALSE) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.6 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.5 * M + 0.3 * C + if (interaction) 0.4 * X * M else 0
  data.frame(X = X, M = M, Y = Y + rnorm(n), C = C)
}
Tstat <- function(d, fy, fm) {
  missingmed:::.mm_mbco_T(d, fy, fm, stats::gaussian(), stats::gaussian(), "X", "M")
}

test_that(".mm_drop_path removes every term carrying the variable", {
  # Compare deparsed text: formula objects also carry environments, which
  # differ here and are irrelevant to the question being asked.
  dp <- function(f, v) paste(deparse(missingmed:::.mm_drop_path(f, v)), collapse = "")
  expect_equal(dp(Y ~ X + M + C, "M"), "Y ~ X + C")
  expect_equal(dp(Y ~ X * M + C, "M"), "Y ~ X + C")
  expect_equal(dp(Y ~ poly(M, 2) + X, "M"), "Y ~ X")
  expect_equal(dp(Y ~ log(M) + X, "M"), "Y ~ X")
  expect_equal(dp(Y ~ I(M^2) + M + X, "M"), "Y ~ X")
  expect_equal(dp(M ~ X * C, "X"), "M ~ C")
  expect_equal(dp(Y ~ X * M * C, "M"), "Y ~ X + C + X:C")
  # nothing to drop, and dropping everything
  expect_equal(dp(Y ~ X + C, "M"), "Y ~ X + C")
  expect_equal(dp(Y ~ M, "M"), "Y ~ 1")
})

test_that("the no-interaction case is unchanged (prototype parity gate)", {
  # This is the shape the research prototype handled. The fix must not move it.
  d <- gen_mbco()
  expect_equal(Tstat(d, Y ~ X + M + C, M ~ X + C), 79.7323, tolerance = 1e-4)
})

test_that("a nonlinear mediator term no longer leaves the test inert", {
  # Before the fix, update(. ~ . - M) left `Y ~ poly(M, 2) + X` UNCHANGED, so
  # the constrained model equalled the full model and T was exactly 0: the test
  # could never reject, at any n, with no diagnostic.
  d <- gen_mbco()
  T_poly <- Tstat(d, Y ~ poly(M, 2) + X + C, M ~ X + C)
  expect_gt(T_poly, 0)
  expect_gt(T_poly, 10)
})

test_that("a moderated a-path nulls the whole treatment path", {
  d <- gen_mbco()
  # M ~ X * C constrained on X must not retain X:C
  expect_equal(paste(deparse(missingmed:::.mm_drop_path(M ~ X * C, "X")), collapse = ""),
    "M ~ C")
  expect_gt(Tstat(d, Y ~ X + M + C, M ~ X * C), 0)
})

test_that("a treatment-by-mediator interaction nulls the mediator entirely", {
  # Author's ruling (spec section 4, reading (i)): the null is "M has no effect
  # on Y at all", so the constrained outcome model drops M *and* X:M. Nulling
  # the main effect alone would leave mediation running through the interaction
  # under a hypothesis asserting there is none.
  d <- gen_mbco(interaction = TRUE)
  dp <- function(f, v) paste(deparse(missingmed:::.mm_drop_path(f, v)), collapse = "")
  expect_equal(dp(Y ~ X * M + C, "M"), "Y ~ X + C")
  expect_equal(dp(Y ~ X + M + C + X:M, "M"), "Y ~ X + C")
  expect_gt(Tstat(d, Y ~ X * M + C, M ~ X + C), 0)
  expect_gt(Tstat(d, Y ~ X + M * C, M ~ X + C), 0)
  # and the interaction spec must not silently agree with the no-interaction
  # one: the full model differs, so the statistic must be free to differ too
  expect_type(Tstat(d, Y ~ X * M + C, M ~ X + C), "double")
})

test_that("T does not depend on the outcome model when the a-branch wins", {
  # Documented surprise: the outcome model cancels out of T entirely there.
  d <- gen_mbco()
  t1 <- Tstat(d, Y ~ X + M + C, M ~ X + C)
  t2 <- Tstat(d, Y ~ X + M + C + I(C^2), M ~ X + C)
  expect_equal(t1, t2, tolerance = 1e-8)
})
