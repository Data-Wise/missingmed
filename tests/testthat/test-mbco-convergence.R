# MBCO refits must converge (SPEC-mbco-convergence-2026-10-08.md).
#
# A glm() fit that did not converge has a log-likelihood at an arbitrary last
# iterate, so 2 * (ll_full - ll_null) is not an LRT. mbco_d4() and
# infer(type = "mbco") refuse, naming the dataset, the branch and the model.

skip_if_not_installed("medfit")
skip_if_not_installed("mice")

# K imputations of one dataset. Each carries a constant `tag` column (its
# imputation number), which the glm stub below uses to find the dataset.
make_imps <- function(K = 3, n = 100, slope = 0.8, separate = integer()) {
  lapply(seq_len(K), function(k) {
    set.seed(100 + k)
    X <- rnorm(n)
    M <- 0.5 * X + rnorm(n)
    Y <- if (k %in% separate) {
      as.integer(M > 0) # completely separated by M
    } else {
      stats::rbinom(n, 1, stats::plogis(slope * M))
    }
    data.frame(X = X, M = M, Y = Y, tag = k)
  })
}

run_d4 <- function(imps, ariv = "fixed") {
  mbco_d4(imps, Y ~ M + X, M ~ X,
    family_y = stats::binomial(), family_m = stats::gaussian(),
    treatment = "X", mediator = "M", ariv = ariv
  )
}

# Replace stats::glm with a wrapper that fits for real, then spoils the result
# when `spoil(formula, data)` is TRUE: either flags it as non-converged or sets
# a non-finite log-likelihood (logLik.glm reads aic).
local_glm_stub <- function(spoil, how = c("converged", "aic"), env = parent.frame()) {
  how <- match.arg(how)
  real <- stats::glm
  stub <- function(formula, ...) {
    fit <- real(formula, ...)
    data <- list(...)$data
    if (spoil(formula, data)) {
      if (how == "converged") fit$converged <- FALSE else fit$aic <- Inf
    }
    fit
  }
  testthat::local_mocked_bindings(glm = stub, .package = "stats", .env = env)
}

f_chr <- function(f) paste(deparse(f), collapse = "")
tag_of <- function(data) unique(data$tag)

test_that("a separated outcome in one imputation refuses, naming it", {
  imps <- make_imps(separate = 2L)
  # Real glm: imputation 2 separates, the others do not.
  expect_error(run_d4(imps), "imputation 2")
  expect_error(run_d4(imps), "full outcome model did not converge")
})

test_that("a converged steep fit is not refused", {
  imps <- make_imps(slope = 8)
  for (k in 1:3) expect_true(stats::glm(Y ~ M + X, data = imps[[k]], family = stats::binomial())$converged)
  r <- run_d4(imps)
  expect_true(is.finite(r["p"]))
})

test_that("each branch and model is named", {
  imps <- make_imps()
  where <- function(formula_txt, tag = NULL) {
    function(formula, data) {
      f_chr(formula) == formula_txt && (is.null(tag) || identical(tag_of(data), tag))
    }
  }
  local({
    local_glm_stub(where("Y ~ M + X", 1L))
    expect_error(run_d4(imps), "imputation 1.*full outcome model did not converge")
  })
  local({
    local_glm_stub(where("Y ~ X", 3L)) # b = 0 drops M from the outcome model
    expect_error(run_d4(imps), "imputation 3.*b = 0 outcome model did not converge")
  })
  local({
    local_glm_stub(where("M ~ 1", 2L)) # a = 0 drops X from the mediator model
    expect_error(run_d4(imps), "imputation 2.*a = 0 mediator model did not converge")
  })
  local({
    local_glm_stub(where("M ~ X", 1L))
    expect_error(run_d4(imps), "imputation 1.*full mediator model did not converge")
  })
})

test_that("a failure only in the stacked data says so", {
  imps <- make_imps()
  local_glm_stub(function(formula, data) length(tag_of(data)) > 1L &&
    f_chr(formula) == "Y ~ X")
  expect_error(run_d4(imps), "the stacked data.*b = 0 outcome model did not converge")
})

test_that("a non-finite log-likelihood refuses", {
  imps <- make_imps()
  local_glm_stub(function(formula, data) identical(tag_of(data), 2L) &&
    f_chr(formula) == "Y ~ M + X", how = "aic")
  expect_error(run_d4(imps), "imputation 2.*full outcome model has a non-finite log-likelihood")
})

test_that("a converged fit carrying glm's 0/1 warning is not refused (C6)", {
  # Near-separated, so glm reports converged = TRUE and warns; the likelihood
  # is finite. The result is returned and glm's own warning still surfaces.
  mk <- function(s, k) {
    set.seed(s)
    n <- 40
    M <- rnorm(n)
    X <- rnorm(n)
    data.frame(X = X, M = M, Y = as.integer(M + rnorm(n, sd = 0.15) > 0), tag = k)
  }
  imps <- Map(mk, c(1, 4, 11), 1:3)
  for (d in imps) {
    g <- suppressWarnings(stats::glm(Y ~ M + X, data = d, family = stats::binomial()))
    expect_true(g$converged)
  }
  expect_warning(r <- run_d4(imps), "numerically 0 or 1")
  expect_true(is.finite(r["p"]))
})

test_that("both ariv settings refuse", {
  imps <- make_imps(separate = 1L)
  expect_error(run_d4(imps, "own"), "did not converge")
  expect_error(run_d4(imps, "fixed"), "did not converge")
})

test_that("converged fits are unchanged (frozen from 0.7.0)", {
  # slope 0.2: the b = 0 branch wins, so the outcome model enters the statistic.
  imps <- make_imps(slope = 0.2)
  expect_identical(run_d4(imps)@stacked_branch, "b")
  fixed <- run_d4(imps, "fixed")
  own <- run_d4(imps, "own")
  expect_equal(unname(fixed[c("D4", "p", "r4", "nu")]), c(0.364426053964996, 0.572925987984925, 1.77059333918642, 4.89708807590402), tolerance = 1e-10)
  expect_equal(unname(own[c("D4", "p", "r4", "nu")]), c(0.364426053964996, 0.572925987984925, 1.77059333918642, 4.89708807590402), tolerance = 1e-10)
})

test_that("infer(type = 'mbco') and sensitivity_mnar() surface the refusal", {
  set.seed(7)
  n <- 150
  d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
  d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
  d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
  d$M[sample(n, 25)] <- NA
  imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M")
  fit <- run(md)
  expect_true(is.finite(infer(fit, type = "mbco")["p"]))
  local_glm_stub(function(formula, data) f_chr(formula) == "Y ~ X + C")
  expect_error(infer(fit, type = "mbco"), "b = 0 outcome model did not converge")
  # The sweep aborts at the first failing rung, and the error names it.
  expect_error(
    sensitivity_mnar(md, target = "M", delta = c(0, 0.5), type = "mbco"),
    "rung 1 of 2.*M = 0.*b = 0 outcome model did not converge"
  )
})
