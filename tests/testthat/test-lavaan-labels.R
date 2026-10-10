# User labels that collide with medfit's default path labels (a, b, cp) must
# not change which paths run() reads (PLAN-codex-review-fixes F1).

skip_if_not_installed("mice")
skip_if_not_installed("lavaan")

gen_lab <- function(n = 300, seed = 52) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rnorm(n)
  M <- .5 * X + .9 * C + rnorm(n)
  Y <- .4 * M + .3 * X + .6 * C + rnorm(n)
  d <- data.frame(X, C, M, Y)
  d$M[1:40] <- NA
  d
}
imp_lab <- mice::mice(gen_lab(),
  m = 3, maxit = 2, method = "norm", printFlag = FALSE,
  seed = 5
)
md_label <- function(model) {
  set_md_mediation(imp_lab,
    model = model, treatment = "X", mediator = "M",
    outcome = "Y", engine = "lavaan"
  )
}
# The role paths from regression on each completed data set.
role_truth <- function() {
  lapply(mice::complete(imp_lab, "all"), function(d) {
    c(
      a = unname(coef(lm(M ~ X + C, d))["X"]),
      b = unname(coef(lm(Y ~ M + X + C, d))["M"]),
      c_prime = unname(coef(lm(Y ~ M + X + C, d))["X"])
    )
  })
}

ok_cases <- list(
  "no labels" = "M ~ X + C\nY ~ M + X + C",
  "labels on the role paths" = "M ~ a*X + C\nY ~ b*M + cp*X + C",
  "cp on a covariate path" = "M ~ a*X + C\nY ~ b*M + cp*C + cx*X",
  "other labels on covariates" = "M ~ am*X + ac*C\nY ~ b*M + cp*X + C"
)

for (nm in names(ok_cases)) {
  test_that(paste("run() reads the role paths:", nm), {
    fit <- run(md_label(ok_cases[[nm]]))
    truth <- role_truth()
    for (i in seq_along(fit@per_imputation)) {
      expect_equal(fit@per_imputation[[i]]@estimates[c("a", "b", "c_prime")],
        truth[[i]],
        tolerance = 1e-4, ignore_attr = TRUE
      )
    }
  })
}

clash_cases <- list(
  "a on the covariate path" = "M ~ am*X + a*C\nY ~ b*M + cp*X + C",
  "a on the covariate path, written first" = "M ~ a*C + am*X\nY ~ b*M + cp*X + C",
  "b on a covariate path" = "M ~ a*X + C\nY ~ bm*M + b*C + cp*X",
  "c_prime on the mediator path" = "M ~ a*X + C\nY ~ c_prime*M + cp*X + C"
)

for (nm in names(clash_cases)) {
  test_that(paste("set_md_mediation() refuses an alias label on another path:", nm), {
    expect_error(md_label(clash_cases[[nm]]), "is the name missingmed uses")
  })
}

test_that("the cross-check in run() stops on an extraction that misreads a path", {
  real <- medfit::extract_mediation
  testthat::local_mocked_bindings(
    extract_mediation = function(object, ...) {
      md <- real(object, ...)
      md@estimates[["a"]] <- md@estimates[["a"]] + 0.4
      md
    },
    .package = "medfit"
  )
  expect_error(run(md_label("M ~ a*X + C\nY ~ b*M + cp*X + C")), "read the `a` path")
})
