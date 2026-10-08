# End-to-end tests: the full public pipeline on simulated data with known
# answers. set_md_mediation() -> run() -> pool() -> infer(), plus
# sensitivity_mnar() and mbco_d4().
#
# Each block asserts something a wrong estimator would fail: agreement with
# mice::pool() run independently on the same imputations, a closed form
# (complete-data lm() / LRT, a Rubin covariance), a data-generating value within
# a few pooled standard errors, or a decision (reject / retain, tipping rung)
# that is known for the fixture. "It runs" is never the only check.

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

# ── helpers ─────────────────────────────────────────────────────────────────

# Gaussian mediator and outcome; X binary, C a confounder of everything.
e2e_gen <- function(n, a, b, cp = 0.25, theta3 = 0) {
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- a * X + 0.3 * C + rnorm(n)
  Y <- cp * X + b * M + theta3 * X * M + 0.3 * C + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C = C)
}

# MAR: missingness in M and Y depends only on the fully observed X and C.
e2e_mar <- function(d, int = -1.5) {
  n <- nrow(d)
  d$M[runif(n) < plogis(int + 0.6 * d$X + 0.6 * d$C)] <- NA
  d$Y[runif(n) < plogis(int + 0.6 * d$X + 0.6 * d$C)] <- NA
  d
}

# One row of missingmed's pooled table, and the matching row of mice::pool().
e2e_row <- function(res, term) res@tidy_table[res@tidy_table$term == term, ]
e2e_mice_row <- function(mira, term) {
  p <- mice::pool(mira)$pooled
  p[p$term == term, ]
}

# Mediation LRT on one complete dataset: 2 * (ll_full - max(ll_{a=0}, ll_{b=0})).
e2e_mbco_T <- function(d) {
  ll <- function(fm, fy) {
    as.numeric(stats::logLik(stats::lm(fm, d))) +
      as.numeric(stats::logLik(stats::lm(fy, d)))
  }
  2 * (ll(M ~ X + C, Y ~ X + M + C) -
    max(ll(M ~ C, Y ~ X + M + C), ll(M ~ X + C, Y ~ X + C)))
}

# Binary mediator under MAR, imputed by pmm (stays 0/1).
e2e_binm_imp <- function() {
  set.seed(1311)
  n <- 400
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- rbinom(n, 1, plogis(-0.3 + 1.1 * X + 0.3 * C))
  Y <- 0.2 * X + 0.8 * M + 0.3 * C + rnorm(n)
  d <- e2e_mar(data.frame(X = X, M = M, Y = Y, C = C))
  mice::mice(d, m = 3, printFlag = FALSE, seed = 1312)
}

# Only M incomplete, for the delta-adjustment blocks.
e2e_sens_md <- function() {
  set.seed(1601)
  d <- e2e_gen(400, a = 0.5, b = 0.45)
  d$M[runif(nrow(d)) < plogis(-1.2 + 0.6 * d$X + 0.6 * d$C)] <- NA
  imp <- mice::mice(d, m = 3, printFlag = FALSE, seed = 1602)
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
}

# Shared Gaussian MI fixture.
e2e_true <- c(a = 0.6, b = 0.35)
e2e_imp <- local({
  set.seed(1131)
  d <- e2e_mar(e2e_gen(400, e2e_true[["a"]], e2e_true[["b"]]))
  mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1132)
})
e2e_md <- set_md_mediation(e2e_imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)
e2e_fit <- run(e2e_md)
e2e_res <- pool(e2e_fit)

# Shared full-data fixture: no missingness, so every imputation is the data.
e2e_full <- local({
  set.seed(1801)
  e2e_gen(400, a = 0.6, b = 0.3)
})
e2e_full_imp <- mice::mice(e2e_full, m = 3, printFlag = FALSE, seed = 1802)
e2e_full_fit <- run(set_md_mediation(e2e_full_imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
))

# ── 1. Gaussian MAR: estimates, MC interval, output methods ─────────────────

test_that("E2E gaussian MI: a and b match mice::pool() on the same imputations", {
  cols <- c("estimate", "ubar", "b", "t", "df", "riv", "fmi")
  mine <- c("estimate", "var_w", "var_b", "var_tot", "df", "riv", "fmi")
  ma <- e2e_mice_row(with(e2e_imp, stats::lm(M ~ X + C)), "X")
  mb <- e2e_mice_row(with(e2e_imp, stats::lm(Y ~ X + M + C)), "M")
  expect_equal(unlist(e2e_row(e2e_res, "a")[mine]), unlist(ma[cols]),
    tolerance = 1e-8, ignore_attr = TRUE
  )
  expect_equal(unlist(e2e_row(e2e_res, "b")[mine]), unlist(mb[cols]),
    tolerance = 1e-8, ignore_attr = TRUE
  )
  expect_gt(e2e_row(e2e_res, "a")$var_b, 0) # the imputations really differ
})

test_that("E2E gaussian MI: the pooled a-b covariance is the between-imputation term", {
  # a and b come from separate regressions, so the within-imputation a-b
  # covariance is 0 and Rubin's total reduces to (1 + 1/m) cov(a_i, b_i).
  cl <- mice::complete(e2e_imp, "all")
  qa <- vapply(cl, function(d) stats::coef(stats::lm(M ~ X + C, d))[["X"]], numeric(1))
  qb <- vapply(cl, function(d) stats::coef(stats::lm(Y ~ X + M + C, d))[["M"]], numeric(1))
  expect_equal(e2e_res@pooled@vcov["a", "b"], (1 + 1 / 3) * stats::cov(qa, qb),
    tolerance = 1e-8
  )
  expect_gt(abs(e2e_res@pooled@vcov["a", "b"]), 1e-4)
})

test_that("E2E gaussian MI: a and b recover the data-generating values", {
  for (p in c("a", "b")) {
    r <- e2e_row(e2e_res, p)
    expect_lt(abs(r$estimate - e2e_true[[p]]), 3 * r$std_error)
  }
  # Each estimate sits closer to its own generating value than to the other
  # path's, so a swap of the a and b labels fails here (for this fixture).
  a_hat <- e2e_row(e2e_res, "a")$estimate
  b_hat <- e2e_row(e2e_res, "b")$estimate
  expect_lt(abs(a_hat - e2e_true[["a"]]), abs(a_hat - e2e_true[["b"]]))
  expect_lt(abs(b_hat - e2e_true[["b"]]), abs(b_hat - e2e_true[["a"]]))
})

test_that("E2E gaussian MI: the MC interval covers the true a*b and excludes 0", {
  set.seed(1103)
  ci <- infer(e2e_fit, type = "mc", n.mc = 1e5)
  expect_named(ci, c("CI", "Estimate", "SE", "MC.Error"))
  ab <- e2e_true[["a"]] * e2e_true[["b"]]
  expect_lt(ci$CI[[1]], ab)
  expect_gt(ci$CI[[2]], ab)
  expect_gt(ci$CI[[1]], 0)
  # The MC point estimate is E[a b] = a*b + cov(a, b) under the pooled normal.
  # cov(a, b) is about 0.002 here and the MC error about 2e-4, so a plug-in
  # a*b, or a dropped a-b covariance, misses this tolerance.
  p <- e2e_res@pooled
  expect_lt(abs(ci$Estimate - (p@a_path * p@b_path + p@vcov["a", "b"])), 1e-3)
  # infer() on the fit and on the pooled result target the same interval.
  set.seed(1103)
  ci2 <- infer(e2e_res, type = "mc", n.mc = 1e5)
  expect_equal(ci2$CI, ci$CI)
})

test_that("E2E gaussian MI: tidy(), print() and summary() report the pooled fit", {
  tt <- tidy(e2e_res)
  expect_s3_class(tt, "tbl_df")
  expect_true(all(c(
    "term", "estimate", "std_error", "var_w", "var_b", "var_tot",
    "statistic", "df", "riv", "fmi", "p_value"
  ) %in% names(tt)))
  expect_setequal(
    tt$term,
    c(
      "m_(Intercept)", "m_X", "m_C", "y_(Intercept)", "y_X", "y_M", "y_C",
      "a", "b", "c_prime"
    )
  )
  ab <- round(e2e_res@pooled@a_path * e2e_res@pooled@b_path, 4)
  expect_output(print(e2e_res), paste0("indirect effect a\\*b = ", ab))
  expect_output(print(e2e_res), "m = 3")
  expect_output(summary(e2e_res), "Rubin's rules")
  expect_output(print(e2e_fit), "per-imputation fits: 3")
  expect_output(print(e2e_md), "imputations \\(m\\)\\s+: 3")
})

# ── 2. MBCO under both ariv rules ───────────────────────────────────────────

test_that("E2E MBCO: strong mediation rejects H0 under ariv = 'fixed' and 'own'", {
  skip_on_cran()
  for (av in c("fixed", "own")) {
    r <- infer(e2e_fit, type = "mbco", ariv = av)
    expect_s3_class(r, "missingmed::MbcoMIResult")
    expect_identical(r@ariv, av)
    expect_equal(r@m, 3)
    expect_gte(r[["p"]], 0)
    expect_lte(r[["p"]], 1)
    expect_lt(r[["p"]], 0.05)
  }
})

test_that("E2E MBCO: no a path (a = 0) does not reject H0", {
  skip_on_cran()
  set.seed(1201)
  d <- e2e_mar(e2e_gen(400, a = 0, b = 0.35))
  imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1202)
  fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
  for (av in c("fixed", "own")) {
    r <- infer(fit, type = "mbco", ariv = av)
    expect_gte(r[["p"]], 0.05)
    expect_lte(r[["p"]], 1)
  }
  # The pooled a covers 0 while b is clearly non-zero: the null is carried by
  # a, which is what a working test must pick up.
  res <- pool(fit)
  a <- e2e_row(res, "a")
  expect_lt(abs(a$estimate), 2 * a$std_error)
  expect_gt(e2e_row(res, "b")$estimate / e2e_row(res, "b")$std_error, 2)
})

test_that("E2E MBCO: with branch mixing, 'fixed' and 'own' give different tests", {
  skip_on_cran()
  # Weak paths, so the imputations disagree on which of a = 0 / b = 0 wins.
  set.seed(1711)
  d <- e2e_mar(e2e_gen(400, a = 0.3, b = 0.12))
  imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1811)
  fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
  rf <- infer(fit, type = "mbco", ariv = "fixed")
  ro <- infer(fit, type = "mbco", ariv = "own")
  expect_true(rf@branch_mix)
  expect_identical(rf@stacked_branch, ro@stacked_branch)
  # The stacked statistic does not depend on ariv; r4 and so D4 and p do.
  expect_equal(rf[["d_S"]], ro[["d_S"]])
  expect_gt(abs(rf[["r4"]] - ro[["r4"]]), 0.1)
  expect_false(isTRUE(all.equal(rf[["p"]], ro[["p"]])))
  for (r in list(rf, ro)) {
    expect_gte(r[["p"]], 0)
    expect_lte(r[["p"]], 1)
  }
})

# ── 3. Non-gaussian families ────────────────────────────────────────────────

test_that("E2E binary outcome: pooled log-odds b matches mice::pool() over glm fits", {
  set.seed(1301)
  n <- 400
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.8 * X + 0.3 * C + rnorm(n)
  Y <- rbinom(n, 1, plogis(-0.2 + 0.25 * X + 0.9 * M + 0.3 * C))
  d <- e2e_mar(data.frame(X = X, M = M, Y = Y, C = C))
  imp <- mice::mice(d, m = 3, printFlag = FALSE, seed = 1302)
  res <- pool(run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_y = stats::binomial()
  )))
  # df and fmi are left out: missingmed uses dfcom = Inf for a binomial model,
  # mice::pool() the residual df.
  mb <- e2e_mice_row(
    with(imp, stats::glm(Y ~ X + M + C, family = stats::binomial())), "M"
  )
  b <- e2e_row(res, "b")
  expect_equal(
    unlist(b[c("estimate", "var_w", "var_b", "var_tot", "riv")]),
    unlist(mb[c("estimate", "ubar", "b", "t", "riv")]),
    tolerance = 1e-6, ignore_attr = TRUE
  )
  expect_lt(abs(b$estimate - 0.9), 3 * b$std_error)
  a <- e2e_row(res, "a")
  expect_lt(abs(a$estimate - 0.8), 3 * a$std_error)
  set.seed(1303)
  ci <- infer(res, type = "mc", n.mc = 5e3)
  expect_gt(ci$CI[[1]], 0)
})

test_that("E2E binary mediator: pooled log-odds a matches mice::pool() over glm fits", {
  imp <- e2e_binm_imp()
  cl <- mice::complete(imp, "all")
  expect_true(all(vapply(cl, function(z) all(z$M %in% c(0, 1)), logical(1))))
  res <- pool(run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_m = stats::binomial()
  )))
  ma <- e2e_mice_row(
    with(imp, stats::glm(M ~ X + C, family = stats::binomial())), "X"
  )
  a <- e2e_row(res, "a")
  expect_equal(
    unlist(a[c("estimate", "var_w", "var_b", "var_tot", "riv")]),
    unlist(ma[c("estimate", "ubar", "b", "t", "riv")]),
    tolerance = 1e-6, ignore_attr = TRUE
  )
  expect_lt(abs(a$estimate - 1.1), 3 * a$std_error)
  b <- e2e_row(res, "b")
  expect_lt(abs(b$estimate - 0.8), 3 * b$std_error)
})

# ── 4. Treatment-by-mediator interaction ───────────────────────────────────

test_that("E2E X:M: the x = 1 and x = 0 estimands differ by a * theta3", {
  set.seed(1401)
  n <- 400
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.6 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.3 * M + 0.45 * X * M + 0.3 * C + rnorm(n)
  d <- e2e_mar(data.frame(X = X, M = M, Y = Y, C = C))
  imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1402)
  fit <- run(set_md_mediation(imp, Y ~ X * M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
  p <- pool(fit)@pooled
  # theta3 is attenuated here (norm imputation omits X*M), so only its sign and
  # the a path are checked against the generating values.
  expect_gt(p@interaction, 0)
  expect_lt(abs(p@a_path - 0.6), 3 * sqrt(p@vcov["a", "a"]))

  set.seed(1403)
  r0 <- infer(fit, type = "mc", treatment_level = 0, n.mc = 1e5)
  set.seed(1403)
  r1 <- infer(fit, type = "mc", treatment_level = 1, n.mc = 1e5)
  expect_identical(r0$Estimand, "a * (b + theta3 * 0)")
  expect_identical(r1$Estimand, "a * (b + theta3 * 1)")
  # E[a (b + theta3)] - E[a b] = a * theta3 + cov(a, theta3). Same seed for both
  # calls, so the MC noise largely cancels. The check targets a * theta3 (about
  # 0.2): an estimand that ignored x, or used theta3 without a, misses it.
  expected <- p@a_path * p@interaction + p@vcov["a", "theta3"]
  expect_lt(abs((r1$Estimate - r0$Estimate) - expected), 2e-3)
  expect_gt(expected, 0.1)
})

# ── 5. IPW vs MI on the same MAR data ───────────────────────────────────────

test_that("E2E IPW: weighted complete-case fits, close to MI but not equal", {
  set.seed(1501)
  d <- e2e_mar(e2e_gen(400, a = 0.5, b = 0.45))
  ipw_fit <- suppressWarnings(run(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw"
  )))
  ipw <- pool(ipw_fit)
  w <- ipw_fit@weights
  cc <- !is.na(w)
  expect_identical(cc, stats::complete.cases(d))
  # Known answer: IPW is lm() on the complete cases with the returned weights.
  wa <- stats::coef(stats::lm(M ~ X + C, d[cc, ], weights = w[cc]))[["X"]]
  wb <- stats::coef(stats::lm(Y ~ X + M + C, d[cc, ], weights = w[cc]))[["M"]]
  expect_equal(ipw@pooled@a_path, wa, tolerance = 1e-8)
  expect_equal(ipw@pooled@b_path, wb, tolerance = 1e-8)
  # The weights do something: IPW is not the unweighted complete-case fit.
  ua <- stats::coef(stats::lm(M ~ X + C, d[cc, ]))[["X"]]
  expect_gt(abs(ipw@pooled@a_path - ua), 1e-4)

  imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1502)
  mi <- pool(run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )))
  for (p in c("a", "b")) {
    e_ipw <- ipw@pooled@estimates[[p]]
    e_mi <- mi@pooled@estimates[[p]]
    se <- max(e2e_row(ipw, p)$std_error, e2e_row(mi, p)$std_error)
    # Both are consistent under MAR, so they agree to well within a standard
    # error -- but they are different estimators, so not exactly.
    expect_lt(abs(e_ipw - e_mi), se)
    expect_gt(abs(e_ipw - e_mi), 1e-6)
    truth <- c(a = 0.5, b = 0.45)[[p]]
    expect_lt(abs(e_ipw - truth), 3 * e2e_row(ipw, p)$std_error)
  }
  set.seed(1503)
  ci <- infer(ipw, type = "mc", n.mc = 5e3)
  expect_gt(ci$CI[[1]], 0)
})

# ── 6. MNAR sensitivity over a delta grid ───────────────────────────────────

test_that("E2E sensitivity: delta = 0 matches MAR; the tipping rung is known", {
  skip_on_cran()
  md <- e2e_sens_md()
  set.seed(1603)
  base <- infer(run(md), type = "mc", n.mc = 5e3)
  sens <- suppressMessages(
    sensitivity_mnar(md, delta = c(0, -2, -4, -6), n.mc = 5e3)
  )
  tb <- tidy(sens)
  expect_equal(tb$M, c(0, -2, -4, -6))
  # delta = 0 is the MAR analysis. Each rung re-imputes with the mids seed,
  # so its MC draws are not `base`'s: compare up to MC noise only.
  expect_lt(abs(tb$estimate[1] - base$Estimate), 0.005)
  expect_gt(tb$conf_low[1], 0)
  expect_gt(base$CI[[1]], 0)
  # Shifting the imputed mediator down moves a * b toward 0 monotonically.
  expect_true(all(diff(tb$estimate) < 0))
  # With one incomplete variable the realized marginal shift tracks delta.
  expect_equal(diff(tb$msp), diff(tb$M), tolerance = 1e-8)
  # The interval first covers 0 at delta = -4, and stays covering at -6.
  covers0 <- tb$conf_low <= 0 & tb$conf_high >= 0
  expect_identical(covers0, c(FALSE, FALSE, TRUE, TRUE))
  s <- summary(sens)
  expect_equal(s$tipping$M, -4)
  expect_output(print(s), "delta = -4")
})

test_that("E2E sensitivity: a grid whose intervals all exclude 0 has no tipping point", {
  skip_on_cran()
  # A positive shift is not the mirror image of a negative one: it raises a
  # but also attenuates b (the shifted mediator no longer tracks the observed
  # outcome), so the indirect effect shrinks here too, just slowly enough
  # that every interval in this short grid still excludes 0.
  sens <- suppressMessages(
    sensitivity_mnar(e2e_sens_md(), delta = c(0, 1, 2), n.mc = 5e3)
  )
  tb <- tidy(sens)
  expect_true(all(tb$conf_low > 0))
  expect_null(summary(sens)$tipping)
  expect_output(print(summary(sens)), "No tipping point")
})

test_that("E2E sensitivity: an mbco curve tips where its p-value crosses alpha", {
  skip_on_cran()
  md <- e2e_sens_md()
  sens <- suppressMessages(
    sensitivity_mnar(md, delta = c(0, -2, -6), type = "mbco")
  )
  tb <- tidy(sens)
  # delta = 0 rung equals MBCO on the MAR imputations (deterministic).
  expect_equal(tb$D4[1], infer(run(md), type = "mbco")[["D4"]])
  expect_true(all(diff(tb$D4) < 0))
  # MBCO is deterministic given the imputation seed, so the rung is known.
  expect_identical(tb$p_value > 0.05, c(FALSE, FALSE, TRUE))
  expect_equal(summary(sens)$tipping$M, -6)
})

# ── 7. mbco_d4() is the same engine as infer(type = "mbco") ─────────────────

test_that("E2E mbco_d4() on completed data equals infer() on a binomial-M fit", {
  skip_on_cran()
  imp <- e2e_binm_imp()
  fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_m = stats::binomial()
  ))
  for (av in c("fixed", "own")) {
    r_fit <- infer(fit, type = "mbco", ariv = av)
    r_raw <- mbco_d4(mice::complete(imp, "all"), Y ~ X + M + C, M ~ X + C,
      family_m = stats::binomial(), treatment = "X", mediator = "M", ariv = av
    )
    expect_identical(S7::S7_data(r_fit), S7::S7_data(r_raw))
    for (prop in c("ariv", "k", "m", "stacked_branch", "branch_mix", "p_branch_a")) {
      expect_identical(S7::prop(r_fit, prop), S7::prop(r_raw, prop))
    }
    expect_lt(r_fit[["p"]], 0.05)
  }
  # Leaving family_m at its gaussian default is a different model, so the
  # statistic must change: the family really reaches the engine.
  r_gauss <- mbco_d4(mice::complete(imp, "all"), Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  expect_false(isTRUE(all.equal(
    r_gauss[["D4"]], infer(fit, type = "mbco")[["D4"]]
  )))
})

# ── 8. Full-data control: no missingness, so B = 0 ──────────────────────────

test_that("E2E full data: MI pools to the plain lm() fit", {
  res <- pool(e2e_full_fit)
  lm_m <- stats::lm(M ~ X + C, e2e_full)
  lm_y <- stats::lm(Y ~ X + M + C, e2e_full)
  a <- e2e_row(res, "a")
  b <- e2e_row(res, "b")
  expect_equal(a$estimate, stats::coef(lm_m)[["X"]], tolerance = 1e-10)
  expect_equal(b$estimate, stats::coef(lm_y)[["M"]], tolerance = 1e-10)
  expect_equal(a$std_error, sqrt(stats::vcov(lm_m)["X", "X"]), tolerance = 1e-10)
  expect_equal(b$std_error, sqrt(stats::vcov(lm_y)["M", "M"]), tolerance = 1e-10)
  expect_equal(c(a$var_b, b$var_b), c(0, 0))
  expect_equal(c(a$riv, b$riv), c(0, 0))
  # With B = 0 the Barnard-Rubin df is (nu + 1) / (nu + 3) * nu for the
  # complete-data residual df nu, not nu itself.
  br <- function(nu) (nu + 1) / (nu + 3) * nu
  expect_equal(a$df, br(stats::df.residual(lm_m)), tolerance = 1e-8)
  expect_equal(b$df, br(stats::df.residual(lm_y)), tolerance = 1e-8)
})

test_that("E2E full data: D4-MBCO reduces to the complete-data LRT", {
  skip_on_cran()
  T0 <- e2e_mbco_T(e2e_full)
  for (av in c("fixed", "own")) {
    r <- infer(e2e_full_fit, type = "mbco", ariv = av)
    expect_equal(r[["D4"]], T0, tolerance = 1e-6)
    expect_equal(r[["d_S"]], T0, tolerance = 1e-6)
    expect_lt(r[["r4"]], 1e-8)
    expect_equal(r[["p"]], stats::pchisq(T0, 1, lower.tail = FALSE), tolerance = 1e-6)
  }
})

test_that("E2E full data: IPW weights are 1 and the fit is the plain lm()", {
  # Every row is complete, so the response-indicator model is degenerate;
  # the weights must still come out as 1.
  fit <- suppressWarnings(run(set_md_mediation(e2e_full, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw"
  )))
  expect_equal(fit@weights, rep(1, nrow(e2e_full)), tolerance = 1e-8)
  est <- fit@per_imputation[[1]]@estimates
  expect_equal(est[["a"]], stats::coef(stats::lm(M ~ X + C, e2e_full))[["X"]], tolerance = 1e-8)
  expect_equal(est[["b"]], stats::coef(stats::lm(Y ~ X + M + C, e2e_full))[["M"]], tolerance = 1e-8)
})
