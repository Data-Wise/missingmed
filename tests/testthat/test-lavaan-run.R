# run() with engine = "lavaan" (SPEC G2/G3; PLAN T2).

skip_if_not_installed("mice")
skip_if_not_installed("lavaan")

gen_run <- function(n = 250, seed = 31) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, .5)
  M <- .5 * X + .3 * C + rnorm(n)
  Y <- .2 * X + .4 * M + .3 * C + rnorm(n)
  d <- data.frame(X, C, M, Y)
  d$M[1:40] <- NA
  d
}
imp_run <- mice::mice(gen_run(),
  m = 3, maxit = 2, method = "norm", printFlag = FALSE,
  seed = 4
)
mod <- "M ~ a*X + C\nY ~ b*M + cp*X + C"
md_lav <- function(...) {
  set_md_mediation(imp_run,
    model = mod, treatment = "X", mediator = "M",
    outcome = "Y", engine = "lavaan", ...
  )
}

test_that("run() returns one named MediationData per imputation", {
  fit <- run(md_lav())
  expect_s3_class(fit, "missingmed::MDMediationFit")
  expect_identical(fit@m, 3L)
  expect_identical(names(fit@per_imputation), names(mice::complete(imp_run, "all")))
  for (f in fit@per_imputation) {
    expect_s3_class(f, "medfit::MediationData")
    expect_identical(f@source_package, "lavaan")
    expect_true(all(c("a", "b", "c_prime") %in% names(f@estimates)))
  }
})

test_that("a, b and c_prime equal the glm fit per imputation (to 1e-6)", {
  lav <- run(md_lav())
  glm <- run(set_md_mediation(imp_run, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
  for (i in seq_along(lav@per_imputation)) {
    k <- c("a", "b", "c_prime")
    expect_equal(lav@per_imputation[[i]]@estimates[k],
      glm@per_imputation[[i]]@estimates[k],
      tolerance = 1e-6
    )
  }
})

test_that("fit_args reach lavaan::sem()", {
  default <- run(md_lav())@per_imputation[[1]]
  robust <- run(md_lav(fit_args = list(se = "robust.sem")))@per_imputation[[1]]
  expect_equal(default@estimates[["a"]], robust@estimates[["a"]], tolerance = 1e-6)
  expect_false(isTRUE(all.equal(sqrt(diag(default@vcov)), sqrt(diag(robust@vcov)))))
})

test_that("extra run() arguments are refused for lavaan", {
  expect_error(run(md_lav(), estimator = "MLR"), "fit_args")
})

test_that("non-convergence refuses once, naming every imputation", {
  fit_real <- .lav_sem
  calls <- 0L
  local_mocked_bindings(.lav_sem = function(model, data, fit_args) {
    calls <<- calls + 1L
    if (calls %in% c(1L, 3L)) {
      # do.fit = FALSE leaves lavaan reporting converged = FALSE.
      fit_args$do.fit <- FALSE
      suppressWarnings(fit_real(model, data, fit_args))
    } else {
      fit_real(model, data, fit_args)
    }
  })
  expect_error(run(md_lav()), "did not converge on imputations 1, 3 of 3")
})

test_that("an improper solution warns once, naming the imputations, and pooling runs", {
  set.seed(3)
  n <- 80
  L <- rnorm(n)
  X <- rnorm(n)
  d <- data.frame(
    X = X, m1 = L + .8 * X, m2 = L + rnorm(n, 0, .01),
    m3 = L + rnorm(n, 0, .01)
  )
  d$Y <- .4 * L + rnorm(n)
  d$Y[1:5] <- NA
  im <- suppressWarnings(
    mice::mice(d, m = 2, maxit = 1, method = "norm", printFlag = FALSE, seed = 1)
  )
  md <- set_md_mediation(im,
    model = "M =~ m1 + m2 + m3\nM ~ X\nY ~ M + X",
    treatment = "X", mediator = "M", outcome = "Y", engine = "lavaan"
  )
  n_warn <- 0L
  fit <- withCallingHandlers(run(md), warning = function(w) {
    n_warn <<- n_warn + 1L
    expect_match(conditionMessage(w), "warned on imputations 1, 2 of 2")
    invokeRestart("muffleWarning")
  })
  expect_identical(n_warn, 1L)
  expect_s3_class(pool(fit), "missingmed::MDMediationResult")
})

test_that("glm run() is unchanged", {
  fit <- run(set_md_mediation(imp_run, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
  expect_identical(fit@per_imputation[[1]]@source_package, "stats::glm")
})
