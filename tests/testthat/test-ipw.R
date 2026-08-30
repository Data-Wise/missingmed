# IPW estimator: set_md_mediation(method = "ipw") -> run -> pool -> infer

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")

# MAR data: missingness in M and Y driven by fully-observed X and C.
make_ipw_data <- function(seed = 2026, n = 600) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[plogis(-1.2 + 0.4 * d$X + 0.4 * d$C) > runif(n)] <- NA
  d$Y[plogis(-1.2 + 0.4 * d$X + 0.4 * d$C) > runif(n)] <- NA
  d
}

test_that("set_md_mediation(method='ipw') accepts a data.frame", {
  d <- make_ipw_data()
  md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw")
  expect_s7_class(md, MDMediationData)
  expect_identical(md@method, "ipw")
  expect_identical(md@se_type, "sandwich")
  expect_equal(md@n_imputations, 1)
  # MI path must still reject a bare data.frame
  expect_error(
    set_md_mediation(d, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M"),
    "mids"
  )
})

test_that("run() on IPW returns MDMediationFit(m=1) with named MediationData + weights", {
  md <- set_md_mediation(make_ipw_data(), Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_trim = 0.99)
  fit <- suppressWarnings(run(md))
  expect_s7_class(fit, MDMediationFit)
  expect_equal(fit@m, 1)
  expect_length(fit@per_imputation, 1)
  expect_s7_class(fit@per_imputation[[1]], medfit::MediationData)
  expect_true(all(c("a", "b", "c_prime") %in% names(fit@per_imputation[[1]]@estimates)))
  # weights: full length, non-negative where present, NA for dropped rows
  expect_length(fit@weights, nrow(make_ipw_data()))
  expect_true(all(fit@weights[!is.na(fit@weights)] >= 0))
  expect_true(anyNA(fit@weights)) # some rows were incomplete and dropped
})

test_that("pool() on an IPW fit has zero between-imputation variance", {
  fit <- suppressWarnings(run(set_md_mediation(make_ipw_data(), Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_trim = 0.99)))
  res <- pool(fit)
  expect_s7_class(res, MDMediationResult)
  expect_true(all(res@tidy_table$var_b == 0))
  expect_equal(res@m, 1)
})

test_that("infer(type='mc') works on IPW; infer(type='mbco') errors", {
  fit <- suppressWarnings(run(set_md_mediation(make_ipw_data(), Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_trim = 0.99)))
  ci <- infer(pool(fit), type = "mc", n.mc = 1e4)
  expect_true(is.numeric(ci$CI) && length(ci$CI) == 2)
  expect_true(ci$CI[1] < ci$CI[2])
  expect_error(infer(fit, type = "mbco"), "IPW")
})

test_that("se_type='sandwich' and 'model' give equal estimates but different vcov", {
  d <- make_ipw_data()
  sw <- suppressWarnings(pool(run(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", se_type = "sandwich", weight_trim = 0.99))))
  mo <- suppressWarnings(pool(run(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", se_type = "model", weight_trim = 0.99))))
  expect_equal(sw@pooled@estimates, mo@pooled@estimates)
  expect_false(isTRUE(all.equal(sw@cov_total, mo@cov_total)))
})

test_that("per-variable weight_formula list is accepted", {
  d <- make_ipw_data()
  md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw",
    weight_formula = list(M = ~ X + C, Y = ~ X + C), weight_trim = 0.99)
  fit <- suppressWarnings(run(md))
  expect_equal(fit@m, 1)
  expect_true(all(c("a", "b") %in% names(fit@per_imputation[[1]]@estimates)))
})

test_that("weight_trim caps extreme weights", {
  d <- make_ipw_data()
  w_full <- missingmed:::.ipw_weights(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_trim = 1))
  w_trim <- missingmed:::.ipw_weights(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_trim = 0.90))
  cc <- !is.na(w_full)
  cap <- stats::quantile(w_full[cc], 0.90, names = FALSE)
  # Trimmed weights are capped at the 90th percentile of the untrimmed weights.
  expect_lte(max(w_trim[cc]), cap + 1e-8)
  expect_lt(max(w_trim[cc]), max(w_full[cc]))
})

# ── Review fix: weights must align to rows when the missingness model has NAs ─

test_that("NAs in a missingness-model predictor do not misalign the weights", {
  d <- make_ipw_data()
  d$X[1:30] <- NA # treatment (stabilization numerator) now incomplete
  md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw"
  )
  expect_no_warning(w <- missingmed:::.ipw_weights(md))
  cc <- stats::complete.cases(d[, c("X", "M", "Y", "C")])
  expect_length(w, nrow(d))
  expect_identical(is.na(w), !cc)
  expect_true(all(w[cc] > 0))
})

test_that("an incomplete weight_formula predictor on a complete case is refused", {
  d <- make_ipw_data()
  d$Z <- rnorm(nrow(d))
  d$Z[which(stats::complete.cases(d))[1:5]] <- NA # Z is not a model variable
  md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_formula = ~ X + Z
  )
  expect_error(missingmed:::.ipw_weights(md), "5 complete-case row")
})

test_that("a weight_formula naming a non-column is refused", {
  d <- make_ipw_data()
  md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw",
    weight_formula = list(Nope = ~ X)
  )
  expect_error(missingmed:::.ipw_weights(md), "Nope")
})
