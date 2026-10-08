# IPW with engine = "lavaan" (SPEC G1; PLAN T6).

skip_if_not_installed("lavaan")

gen_ipw <- function(n = 500, seed = 61) {
  set.seed(seed)
  d <- data.frame(X = rbinom(n, 1, .5), C = rnorm(n))
  d$M <- .5 * d$X + .3 * d$C + rnorm(n)
  d$Y <- .2 * d$X + .4 * d$M + .3 * d$C + rnorm(n)
  d$M[runif(n) < plogis(-1 + .8 * d$C)] <- NA
  d
}
dat <- gen_ipw()
mod <- "M ~ a*X + C\nY ~ b*M + cp*X + C"
md_li <- function(...) {
  set_md_mediation(dat,
    model = mod, treatment = "X", mediator = "M", outcome = "Y",
    engine = "lavaan", method = "ipw", ...
  )
}
md_gi <- function() {
  set_md_mediation(dat, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw"
  )
}

test_that("lavaan IPW point estimates equal the glm IPW path (to 1e-6)", {
  l <- run(md_li())@per_imputation[[1]]@estimates
  g <- run(md_gi())@per_imputation[[1]]@estimates
  k <- c("a", "b", "c_prime")
  expect_equal(l[k], g[k], tolerance = 1e-6)
})

test_that("IPW + lavaan runs through pool() and infer('mc')", {
  fit <- run(md_li())
  expect_equal(fit@m, 1)
  res <- pool(fit)
  expect_true(all(is.finite(res@tidy_table$estimate)))
  set.seed(2)
  expect_true(all(is.finite(infer(fit, type = "mc", n.mc = 5000)$CI)))
})

test_that("SEs are robust: they differ from the unweighted ML SEs", {
  w <- run(md_li())@per_imputation[[1]]
  cc <- dat[complete.cases(dat), ]
  naive <- lavaan::sem(mod, cc)
  expect_false(isTRUE(all.equal(
    unname(w@vcov["a", "a"]),
    unname(lavaan::vcov(naive)["a", "a"])
  )))
})

test_that("a non-robust se, a sandwich-less estimator or se_type = 'model' errors", {
  expect_error(md_li(fit_args = list(se = "standard")), "SEs must be robust")
  expect_error(md_li(fit_args = list(se = "bootstrap")), "SEs must be robust")
  expect_error(md_li(fit_args = list(estimator = "GLS")), "no sandwich SEs")
  expect_error(md_li(se_type = "model"), "always robust")
  expect_error(md_li(fit_args = list(sampling.weights = "w")), "sampling.weights")
})

test_that("an allowed robust se or MLR estimator is accepted", {
  expect_s3_class(md_li(fit_args = list(se = "robust.huber.white")), "missingmed::MDMediationData")
  expect_s3_class(md_li(fit_args = list(estimator = "MLR")), "missingmed::MDMediationData")
})

test_that("extra run() arguments are refused for lavaan IPW", {
  expect_error(run(md_li(), foo = 1), "fit_args")
})

test_that("glm IPW is unchanged", {
  expect_identical(run(md_gi())@per_imputation[[1]]@source_package, "stats::glm")
})
