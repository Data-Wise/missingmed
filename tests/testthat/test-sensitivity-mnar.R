# MNAR sensitivity: delta-adjusted imputation across a grid.

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

gen_mnar <- function(n = 400, seed = 4) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.6 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.5 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < plogis(-1.2 + 0.5 * X + 0.5 * C)] <- NA
  d
}
md_mi <- function(m = 5, seed = 99, ...) {
  # Materialise the data BEFORE calling mice(). Passing `gen_mnar(...)` inline
  # hands mice() a promise, which R forces only after mice() has called
  # set.seed(seed) -- so gen_mnar()'s own set.seed() lands afterwards and
  # silently overrides it, making the "seeded" imputation unreproducible.
  d <- gen_mnar(...)
  imp <- mice::mice(d, m = m, printFlag = FALSE, seed = seed)
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
}

test_that("delta = 0 reproduces the MAR analysis exactly", {
  # Asserted on MBCO, which is deterministic. The Monte-Carlo CI is NOT usable
  # for this check: ci_mediation_data() draws n.mc samples, so two calls on
  # identical pooled input differ by MC noise and the test would fail for a
  # reason that has nothing to do with imputation.
  md <- md_mi()
  sens <- suppressMessages(sensitivity_mnar(md, delta = 0, type = "mbco"))
  base <- infer(run(md), type = "mbco")
  expect_equal(unname(sens@rungs[[1]][["D4"]]), unname(base[["D4"]]))
  expect_equal(sens@seed, 99)
  expect_equal(sens@seed_source, "mids")
})

test_that("a monotone delta grid moves the indirect effect monotonically", {
  # Direction only. The realized shift is NOT equal to delta (see the msp test),
  # so asserting a magnitude here would be asserting the wrong thing.
  md <- md_mi()
  sens <- suppressMessages(
    sensitivity_mnar(md, delta = c(0, -0.5, -1, -1.5), n.mc = 3e3)
  )
  tb <- tidy(sens)
  expect_equal(nrow(tb), 4L)
  expect_true(all(diff(tb$estimate) < 0))
  expect_true(all(tb$conf_low < tb$conf_high))
})

test_that("the realized MSP is reported and differs from the supplied CSP", {
  # The CSP/MSP gap is the headline failure mode of this method (Tompsett et al.
  # 2018): users supply a marginal quantity where a conditional one is expected.
  # Reporting msp is how a user can see the gap rather than assume it away.
  md <- md_mi()
  sens <- suppressMessages(sensitivity_mnar(md, delta = c(0, -2), n.mc = 3e3))
  tb <- tidy(sens)
  expect_true("msp" %in% names(tb))
  expect_true(all(is.finite(tb$msp)))
  # Even at delta = 0 the MSP is non-zero: missingness depends on X and C, so
  # MAR-imputed values legitimately differ from observed ones. This alone is
  # worth surfacing -- a user reading delta = 0 as "no departure" is right about
  # the assumption but wrong about the realised marginal difference.
  expect_false(isTRUE(all.equal(tb$msp[1], 0)))
  # With a SINGLE incomplete variable the increments coincide: there is no other
  # incomplete variable for the shift to feed back through, so the CSP/MSP gap
  # in the increment is zero. The gap is a chained-equations effect, not an
  # intrinsic property of delta adjustment -- see the multivariate test below.
  expect_equal(tb$msp[2] - tb$msp[1], -2)
})

test_that("the CSP/MSP increment gap appears once a second variable is incomplete", {
  # Two incomplete variables: the shift on M re-enters Y's imputation model and
  # Y re-enters M's on the next cycle, so the realised marginal shift no longer
  # equals the supplied delta. This is the mechanism behind Tompsett et al.'s
  # warning, reproduced here so a regression in the msp computation is visible.
  d <- gen_mnar()
  d$Y[runif(nrow(d)) < plogis(-1.4 + 0.5 * d$X + 0.5 * d$C)] <- NA
  imp <- mice::mice(d, m = 4, printFlag = FALSE, seed = 21)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  sens <- suppressMessages(sensitivity_mnar(md, delta = c(0, -2), n.mc = 2e3))
  tb <- tidy(sens)
  gap <- (tb$msp[2] - tb$msp[1]) - (-2)
  expect_false(isTRUE(all.equal(gap, 0)))
})

test_that("a user's existing post entry survives re-imputation", {
  d <- gen_mnar()
  post <- mice::make.post(d)
  post["M"] <- "imp[[j]][, i] <- pmax(imp[[j]][, i], -1)"
  imp <- mice::mice(d, m = 3, post = post, printFlag = FALSE, seed = 5)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  sens <- suppressMessages(sensitivity_mnar(md, delta = 1, n.mc = 2e3))
  expect_s7_class(sens, MDSensitivityResult)
  expect_equal(nrow(tidy(sens)), 1L)
})

test_that("a data.frame grid drives one rung per row", {
  md <- md_mi()
  g <- data.frame(M = c(0, -1))
  sens <- suppressMessages(sensitivity_mnar(md, delta = g, n.mc = 2e3))
  expect_equal(nrow(tidy(sens)), 2L)
  expect_equal(sens@target, "M")
})

# ── documented refusals ─────────────────────────────────────────────────────

test_that("IPW is refused with guidance", {
  d <- gen_mnar()
  md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw"
  )
  expect_error(sensitivity_mnar(md, delta = 1), "not available for method")
})

test_that("a fully observed target is refused, not silently a no-op", {
  md <- md_mi()
  expect_error(sensitivity_mnar(md, delta = 1, target = "C"), "no missing values")
})

test_that("an unknown target is refused", {
  md <- md_mi()
  expect_error(sensitivity_mnar(md, delta = 1, target = "nope"), "not a column")
})

test_that("a categorical target is refused, naming the reason", {
  set.seed(8)
  n <- 300
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  Mb <- rbinom(n, 1, plogis(-0.2 + 1.2 * X + 0.3 * C))
  Y <- 0.2 * X + 1.0 * Mb + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = factor(Mb), Y = Y, C = C)
  d$M[sample(n, 60)] <- NA
  imp <- mice::mice(d, m = 3, printFlag = FALSE, seed = 8)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_m = stats::binomial()
  )
  expect_error(sensitivity_mnar(md, delta = 1), "not yet implemented")
})

test_that("target must be NULL when delta is a data frame", {
  md <- md_mi()
  expect_error(
    sensitivity_mnar(md, delta = data.frame(M = 0), target = "M"),
    "must be NULL"
  )
})

# ── D1: mechanism is derived, not user-set ──────────────────────────────────

test_that("mechanism = 'mnar' is deprecated and ignored", {
  d <- gen_mnar()
  imp <- mice::mice(d, m = 2, printFlag = FALSE, seed = 3)
  expect_warning(
    md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
      treatment = "X", mediator = "M", mechanism = "mnar"
    ),
    "deprecated"
  )
  expect_equal(md@mechanism, "mar")
})

test_that("sensitivity_mnar stamps mechanism on the objects it creates", {
  md <- md_mi()
  expect_equal(md@mechanism, "mar")
  sens <- suppressMessages(sensitivity_mnar(md, delta = 0, type = "mbco"))
  expect_equal(sens@source@mechanism, "mar") # the original is untouched
  expect_s7_class(sens, MDSensitivityResult)
})
