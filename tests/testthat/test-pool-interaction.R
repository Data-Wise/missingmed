# pool() and infer(type = "mc") on models with a treatment-by-mediator
# interaction (issue #20).

make_xm_fit <- function() {
  set.seed(101)
  n <- 400
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.3 * M + 0.4 * X * M + 0.3 * C + rnorm(n)
  d <- data.frame(X, M, Y, C)
  d$M[sample(n, 60)] <- NA
  d$Y[sample(n, 60)] <- NA
  imp <- mice::mice(d, m = 5, method = "norm", printFlag = FALSE, seed = 1)
  run(set_md_mediation(imp, Y ~ X * M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
}

xm_fit <- make_xm_fit()
xm_res <- missingmed::pool(xm_fit)

test_that("pool() returns a valid pooled InteractionMediationData (#20 reprex)", {
  p <- xm_res@pooled
  expect_true(S7::S7_inherits(p, medfit::InteractionMediationData))
  q <- p@estimates
  expect_equal(p@a_path, unname(q[["a"]]))
  expect_equal(p@b_path, unname(q[["b"]]))
  expect_equal(p@interaction, unname(q[["theta3"]]))
  # The decomposition is recomputed from the pooled paths.
  expect_equal(p@pie, p@a_path * p@b_path)
  expect_equal(p@int_med, p@interaction * p@a_path)
  expect_equal(p@nie, p@a_path * (p@b_path + p@interaction))
  expect_equal(p@nde, p@cde + p@int_ref)
  # theta3 is pooled with Rubin's rules like every other estimate.
  th <- vapply(xm_fit@per_imputation, function(d) d@interaction, numeric(1))
  expect_equal(p@interaction, mean(th))
})

# A covariate that is itself imputed makes m_ref (the mediator's expected
# value at the reference treatment with covariates at their means) differ
# across imputations; a factor covariate checks the coefficient/mean naming.
make_xm_fit_cov <- function() {
  set.seed(202)
  n <- 400
  C <- rnorm(n)
  G <- factor(sample(c("u", "v", "w"), n, replace = TRUE))
  X <- rbinom(n, 1, 0.5)
  M <- 0.5 * X + 0.3 * C + 0.4 * (G == "v") + rnorm(n)
  Y <- 0.2 * X + 0.3 * M + 0.4 * X * M + 0.3 * C + rnorm(n)
  d <- data.frame(X, M, Y, C, G)
  d$M[sample(n, 60)] <- NA
  d$C[sample(n, 80)] <- NA
  imp <- mice::mice(d, m = 5, printFlag = FALSE, seed = 4,
    method = c(X = "", M = "norm", Y = "", C = "norm", G = "")
  )
  run(set_md_mediation(imp, Y ~ X * M + C + G, M ~ X + C + G,
    treatment = "X", mediator = "M"
  ))
}

test_that("pooled int_ref comes from one pooled reference profile", {
  fit <- make_xm_fit_cov()
  fits <- fit@per_imputation
  m_ref <- vapply(fits, missingmed:::.interaction_m_ref, numeric(1))
  int_ref_i <- vapply(fits, function(x) x@int_ref, numeric(1))
  th_i <- vapply(fits, function(x) x@interaction, numeric(1))
  m_star <- fits[[1]]@m_star
  expect_equal(th_i * (m_ref - m_star), int_ref_i, tolerance = 1e-10)
  # The theta3 = 0 fallback (intercept plus covariate terms at medfit's stored
  # means, factor covariate included) gives the same m_ref. medfit < 0.4.0
  # stores no means, so this part needs a newer medfit.
  if (!is.null(attr(fits[[1]]@data, "medfit_covariate_means"))) {
    rebuilt <- vapply(fits, function(x) {
      S7::props(x) <- list(
        interaction = 0, int_med = 0, int_ref = 0,
        cde = x@c_prime, nde = x@c_prime, nie = x@pie,
        total_effect = x@c_prime + x@pie
      )
      missingmed:::.interaction_m_ref(x)
    }, numeric(1))
    expect_equal(rebuilt, m_ref, tolerance = 1e-10)
  }
  expect_gt(diff(range(m_ref)), 1e-3) # the imputed covariate moves m_ref
  p <- missingmed::pool(fit)@pooled
  expect_equal(p@int_ref, p@interaction * (mean(m_ref) - m_star), tolerance = 1e-12)
  # Not the average of the per-imputation int_ref, which mixes each
  # imputation's theta3 with its own m_ref.
  expect_gt(abs(p@int_ref - mean(int_ref_i)), 1e-8)
  expect_equal(p@nde, p@cde + p@int_ref)
})

test_that("pool() refuses imputations fitted at different m_star", {
  fit <- xm_fit
  o <- fit@per_imputation[[2]]
  m_ref <- missingmed:::.interaction_m_ref(o)
  ms <- 1
  cde <- o@c_prime + o@interaction * ms
  int_ref <- o@interaction * (m_ref - ms)
  S7::props(o) <- list(
    m_star = ms, cde = cde, int_ref = int_ref, nde = cde + int_ref,
    total_effect = cde + int_ref + o@int_med + o@pie
  )
  pis <- fit@per_imputation
  pis[[2]] <- o
  fit@per_imputation <- pis
  expect_error(missingmed::pool(fit), "different mediator reference levels")
})

test_that("theta3 and b0 rows take their source rows' df", {
  tt <- xm_res@tidy_table
  row <- function(t) tt[tt$term == t, c("df", "p_value")]
  expect_equal(row("theta3"), row("y_X:M"), ignore_attr = TRUE)
  expect_equal(row("b0"), row("m_(Intercept)"), ignore_attr = TRUE)
})

test_that("infer(type = 'mc') on an X:M fit needs a valid treatment_level", {
  expect_error(infer(xm_fit, type = "mc"), "treatment_level")
  expect_error(infer(xm_res, type = "mc"), "treatment_level")
  expect_error(infer(xm_fit, type = "mc", treatment_level = c(0, 1)), "single")
  expect_error(infer(xm_fit, type = "mc", treatment_level = "1"), "single")
})

test_that("the MC interval targets a * (b + theta3 * x)", {
  p <- xm_res@pooled
  keep <- c("a", "b", "theta3")
  mu <- p@estimates[keep]
  S <- p@vcov[keep, keep]
  n_mc <- 2e5
  for (x in c(0, 1)) {
    set.seed(11)
    r <- infer(xm_fit, type = "mc", treatment_level = x, n.mc = n_mc)
    expect_identical(r$Estimand, paste0("a * (b + theta3 * ", x, ")"))
    expect_named(r, c("CI", "Estimate", "SE", "MC.Error", "Estimand"))
    # Known answer: E[a (b + theta3 x)] for (a, b, theta3) ~ N(mu, S).
    expected <- mu[["a"]] * (mu[["b"]] + mu[["theta3"]] * x) +
      S["a", "b"] + x * S["a", "theta3"]
    expect_lt(abs(r$Estimate - expected), 5 * r$SE / sqrt(n_mc))
    # Independent draws from the same normal give the same interval.
    set.seed(12)
    z <- matrix(rnorm(3 * n_mc), ncol = 3) %*% chol(S)
    draws <- (mu[["a"]] + z[, 1]) *
      ((mu[["b"]] + z[, 2]) + (mu[["theta3"]] + z[, 3]) * x)
    q <- unname(stats::quantile(draws, c(0.025, 0.975)))
    expect_lt(max(abs(unname(r$CI) - q)), 0.01)
  }
  # x = 1 and x = 0 bracket the pooled TNIE and PNIE point estimates.
  set.seed(13)
  r1 <- infer(xm_res, type = "mc", treatment_level = 1)
  expect_true(r1$CI[[1]] < p@nie && p@nie < r1$CI[[2]])
  r0 <- infer(xm_res, type = "mc", treatment_level = 0)
  expect_true(r0$CI[[1]] < p@pie && p@pie < r0$CI[[2]])
})

test_that("treatment_level is refused on a model without X:M", {
  set.seed(3)
  n <- 250
  d <- data.frame(X = rnorm(n), C = rnorm(n))
  d$M <- 0.4 * d$X + 0.3 * d$C + rnorm(n)
  d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
  d$M[sample(n, 30)] <- NA
  imp <- mice::mice(d, m = 2, method = "norm", printFlag = FALSE, seed = 1)
  fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
  expect_error(infer(fit, type = "mc", treatment_level = 1), "no.*interaction|has none")
  expect_named(infer(fit, type = "mc"), c("CI", "Estimate", "SE", "MC.Error"))
})

test_that("print(), summary() and tidy() report the X:M indirect effect", {
  expect_output(print(xm_res), "at x = 0")
  expect_output(print(xm_res), "treatment_level")
  expect_output(summary(xm_res), "a\\*\\(b \\+ theta3\\*x\\)")
  expect_output(print(xm_fit), "at X = 0")
  tt <- tidy(xm_res)
  expect_true(all(c("theta3", "b0") %in% tt$term))
})

test_that("sensitivity_mnar(type = 'mc') passes treatment_level through", {
  md <- xm_fit@source
  expect_error(
    suppressMessages(sensitivity_mnar(md, delta = 0, type = "mc", n.mc = 1e3)),
    "treatment_level"
  )
  sens <- suppressMessages(sensitivity_mnar(md,
    delta = c(0, 0.5), type = "mc", n.mc = 1e3, treatment_level = 1
  ))
  expect_length(sens@rungs, 2)
  expect_identical(sens@rungs[[1]]$Estimand, "a * (b + theta3 * 1)")
})

test_that("MBCO is unchanged on the same X:M fit", {
  r <- infer(xm_fit, type = "mbco", ariv = "fixed")
  expect_s3_class(r, "missingmed::MbcoMIResult")
  expect_true(is.finite(r[["p"]]))
})
