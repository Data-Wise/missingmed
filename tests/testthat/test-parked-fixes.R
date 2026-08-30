# Fixes from PLAN-parked-findings-2026-08-30.md (items 1, 2, 4).

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

pk_data <- function(n = 300, seed = 2) {
  set.seed(seed)
  C <- rnorm(n); X <- rbinom(n, 1, 0.5)
  M <- 0.6 * X + rnorm(n); Y <- 0.2 * X + 0.5 * M + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < 0.25] <- NA
  d
}
pk_md <- function(...) {
  imp <- mice::mice(pk_data(), m = 3, maxit = 3, printFlag = FALSE, seed = 1)
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", ...)
}

# ── Item 1: infer() must honour @conf_level ─────────────────────────────────

test_that("infer() uses the object's conf_level instead of a hard-coded 0.95", {
  res <- pool(run(pk_md(conf_level = 0.90)))
  expect_equal(res@conf_level, 0.90)
  set.seed(1); a <- infer(res, type = "mc", n.mc = 20000)
  set.seed(1); b <- infer(res, type = "mc", level = 0.90, n.mc = 20000)
  expect_equal(diff(a$CI), diff(b$CI), tolerance = 1e-8)
})

test_that("an explicit level= still overrides the object", {
  res <- pool(run(pk_md(conf_level = 0.90)))
  set.seed(1); narrow <- infer(res, type = "mc", n.mc = 20000)
  set.seed(1); wide <- infer(res, type = "mc", level = 0.99, n.mc = 20000)
  expect_gt(diff(wide$CI), diff(narrow$CI))
})

test_that("the default is still 0.95 when conf_level was never set", {
  res <- pool(run(pk_md()))
  expect_equal(res@conf_level, 0.95)
  set.seed(1); a <- infer(res, type = "mc", n.mc = 20000)
  set.seed(1); b <- infer(res, type = "mc", level = 0.95, n.mc = 20000)
  expect_equal(diff(a$CI), diff(b$CI), tolerance = 1e-8)
})

test_that("an out-of-range conf_level is refused at construction, not by RMediation", {
  # Previously only MDMediationData validated this, so a bad value reached
  # checkmate inside RMediation and named an argument the user never passed.
  fit <- run(pk_md())
  expect_error(S7::set_props(fit, conf_level = 1.5), "conf_level")
  expect_error(S7::set_props(fit, conf_level = NA_real_), "conf_level")
  res <- pool(fit)
  expect_error(S7::set_props(res, conf_level = numeric()), "conf_level")
})

# ── Item 2: the pooled object must not carry imputation 1's nuisance params ──

test_that("pool() does not present imputation 1's residual SDs as pooled", {
  fit <- run(pk_md()); res <- pool(fit)
  sig <- vapply(fit@per_imputation, function(x) x@sigma_m, numeric(1))
  expect_gt(stats::sd(sig), 0)          # they genuinely differ across imputations
  expect_null(res@pooled@sigma_m)
  expect_null(res@pooled@sigma_y)
  expect_null(res@pooled@data)
})

test_that("pool() keeps what IS common and the CI path is unaffected", {
  fit <- run(pk_md()); res <- pool(fit)
  n_obs <- vapply(fit@per_imputation, function(x) x@n_obs, numeric(1))
  expect_equal(length(unique(n_obs)), 1L)   # identical, so keeping it is correct
  expect_equal(res@pooled@n_obs, n_obs[[1]])
  expect_type(res@pooled@converged, "logical")
  ci <- infer(res, type = "mc", n.mc = 5000)
  expect_true(all(is.finite(ci$CI)))
})

# ── Item 4: tipping point by smallest |delta|, and mbco participates ─────────

test_that("the tipping point is the smallest departure, not the first supplied", {
  md <- pk_md()
  sens <- suppressMessages(
    sensitivity_mnar(md, delta = c(-2, 0, -1), type = "mc", n.mc = 5000)
  )
  s <- summary(sens)
  if (!is.null(s$tipping)) {
    # whatever it reports must be the smallest |delta| among retained rungs
    tb <- tidy(sens)
    keep <- !(tb$conf_low > 0 | tb$conf_high < 0)
    expect_equal(abs(s$tipping[[1L]]), min(abs(sens@grid[[1]][keep])))
  }
  expect_s3_class(s, "summary.MDSensitivityResult")
})

test_that("an mbco curve carries the alpha its predicate needs", {
  md <- pk_md()
  sens <- suppressMessages(sensitivity_mnar(md, delta = c(0, -1), type = "mbco"))
  expect_equal(sens@level, 0.95)
  # the predicate must at least be reachable: it returns a logical, not NULL
  tb <- tidy(sens)
  expect_true("p_value" %in% names(tb))
  expect_type(missingmed:::.mnar_null_retained(sens, tb), "logical")
})

test_that("a null result at MAR is not reported as a tipping point", {
  # If the interval already covers 0 at delta = 0 there is nothing to tip: the
  # analysis is null before any departure from MAR is assumed. Asserted on the
  # helper directly so the test cannot silently become empty.
  md <- pk_md()
  sens <- suppressMessages(
    sensitivity_mnar(md, delta = c(0, -1), type = "mc", n.mc = 5000)
  )
  tb <- tidy(sens)
  # force the MAR rung to retain the null, whatever the data did
  tb$conf_low[1] <- -1; tb$conf_high[1] <- 1
  tb$conf_low[2] <- 0.1; tb$conf_high[2] <- 0.5
  expect_null(missingmed:::.mnar_tipping(sens, tb))
})
