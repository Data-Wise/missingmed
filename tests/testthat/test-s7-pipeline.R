# S7 pipeline: set_md_mediation -> run -> pool -> infer (+ accessor, MBCO parity)

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

# Helpers mirroring research/Missing Effect/code/prototype-d4-mbco.R ----------
gen_data <- function(n, a, b, cp = 0.2) {
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- a * X + 0.3 * C + rnorm(n)
  Y <- cp * X + b * M + 0.3 * C + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C = C)
}
impose_mar <- function(d, int) {
  d$M[runif(nrow(d)) < plogis(int + 0.5 * d$X + 0.5 * d$C)] <- NA
  d$Y[runif(nrow(d)) < plogis(int + 0.5 * d$X + 0.5 * d$C)] <- NA
  d
}
proto_ll_med <- function(d, drop_a = FALSE, drop_b = FALSE) {
  fm <- if (drop_a) M ~ C else M ~ X + C
  fy <- if (drop_b) Y ~ X + C else Y ~ X + M + C
  as.numeric(stats::logLik(lm(fm, d))) + as.numeric(stats::logLik(lm(fy, d)))
}
proto_mbco_T <- function(d) {
  2 * (proto_ll_med(d) - max(proto_ll_med(d, drop_a = TRUE), proto_ll_med(d, drop_b = TRUE)))
}
proto_d4 <- function(implist) {
  K <- length(implist)
  d_k <- vapply(implist, proto_mbco_T, 0)
  dbar <- mean(d_k)
  d_S <- proto_mbco_T(do.call(rbind, implist)) / K
  r4 <- max(0, (K + 1) / (1 * (K - 1)) * (dbar - d_S))
  D4 <- d_S / (1 * (1 + r4))
  c(D4 = D4, r4 = r4, d_S = d_S)
}

make_md <- function(seed, n, a, b, int = qlogis(0.25), m = 10) {
  set.seed(seed)
  imp <- mice::mice(impose_mar(gen_data(n, a, b), int),
    m = m, method = "norm", printFlag = FALSE)
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M")
}

test_that("set_md_mediation builds a valid MDMediationData", {
  md <- make_md(1, 150, 0.4, 0.4, m = 3)
  expect_s7_class(md, MDMediationData)
  expect_identical(md@method, "mi")
  expect_identical(md@treatment, "X")
  expect_true(md@n_imputations == 3)
})

test_that("run() yields a list of named medfit::MediationData (one per imputation)", {
  fit <- run(make_md(2, 150, 0.4, 0.4, m = 4))
  expect_s7_class(fit, MDMediationFit)
  expect_length(fit@per_imputation, 4)
  mi1 <- fit@per_imputation[[1]]
  expect_s7_class(mi1, medfit::MediationData)
  expect_true(all(c("a", "b", "c_prime") %in% names(mi1@estimates)))
  expect_true(all(c("a", "b") %in% rownames(mi1@vcov)))
})

test_that("pool() returns a named pooled MediationData valid for RMediation", {
  res <- pool(run(make_md(3, 200, 0.4, 0.4, m = 10)))
  expect_s7_class(res, MDMediationResult)
  expect_s7_class(res@pooled, medfit::MediationData)
  expect_true(all(c("a", "b", "c_prime") %in% names(res@pooled@estimates)))
  ci <- RMediation::ci_mediation_data(res@pooled, level = 0.95, type = "MC", n.mc = 1e4)
  expect_true(is.numeric(ci$CI) && length(ci$CI) == 2)
  expect_true(ci$CI[1] < ci$CI[2])
})

test_that("unnamed pooled estimates error out (RMediation >= 1.5.0 contract)", {
  # RMediation < 1.5.0 resolved the a/b paths positionally and silently fell back
  # to assuming cov(a, b) = 0 when it could not identify them -- a wrong CI rather
  # than an error. From 1.5.0 the extraction is strictly name-based. pool() always
  # emits named estimates + dimnamed vcov, so this locks in the contract that makes
  # the DESCRIPTION floor meaningful.
  res <- pool(run(make_md(5, 150, 0.4, 0.4, m = 3)))
  stripped <- res@pooled
  est <- stripped@estimates
  names(est) <- NULL
  vc <- stripped@vcov
  dimnames(vc) <- NULL
  stripped@estimates <- est
  stripped@vcov <- vc
  expect_error(
    RMediation::ci_mediation_data(stripped, level = 0.95, type = "MC", n.mc = 1e3),
    "Cannot resolve path parameters by name"
  )
})

test_that("per_imputation_list() exposes the list + m for MBCO", {
  fit <- run(make_md(4, 150, 0.4, 0.4, m = 5))
  acc <- per_imputation_list(fit)
  expect_named(acc, c("per_imputation", "m"))
  expect_length(acc$per_imputation, 5)
  expect_equal(acc$m, 5)
  expect_equal(n_imputations(fit), 5)
})

test_that("infer(type='mc') and infer(type='mbco') both run", {
  fit <- run(make_md(5, 200, 0.39, 0.2, m = 10))
  mc <- infer(fit, type = "mc", n.mc = 1e4)
  expect_true(is.numeric(mc$CI) && length(mc$CI) == 2)
  mb <- infer(fit, type = "mbco")
  expect_true(all(c("D4", "p", "r4", "nu", "d_S") %in% names(mb)))
  # MBCO on the pooled result must error (does not commute with Rubin's rules)
  expect_error(infer(pool(fit), type = "mbco"), "commute")
})

test_that("MBCO D4 matches the prototype exactly on >= 3 cells", {
  cells <- list(
    list(seed = 20260611, n = 200, a = 0.39, b = 0, int = qlogis(0.25)),
    list(seed = 20260612, n = 200, a = 0.00, b = 0, int = qlogis(0.25)),
    list(seed = 20260613, n = 300, a = 0.39, b = 0, int = qlogis(0.10))
  )
  for (cl in cells) {
    set.seed(cl$seed)
    imp <- mice::mice(impose_mar(gen_data(cl$n, cl$a, cl$b), cl$int),
      m = 10, method = "norm", printFlag = FALSE)
    proto <- proto_d4(mice::complete(imp, "all"))
    md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M")
    mine <- infer(run(md), type = "mbco")
    expect_equal(unname(mine["D4"]), unname(proto["D4"]), tolerance = 1e-6)
    expect_equal(unname(mine["r4"]), unname(proto["r4"]), tolerance = 1e-6)
    expect_equal(unname(mine["d_S"]), unname(proto["d_S"]), tolerance = 1e-6)
  }
})
