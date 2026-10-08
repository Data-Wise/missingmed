# set_md_mediation(engine = "lavaan"): object construction and pre-fit
# validation (SPEC-s7-sem-engine, Q1/G3; PLAN T1).

skip_if_not_installed("mice")
skip_if_not_installed("lavaan")

gen_lav <- function(n = 200, seed = 21) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, .5)
  L <- .5 * X + .3 * C + rnorm(n)
  data.frame(
    X, C,
    M = L + rnorm(n, 0, .5),
    m1 = L + rnorm(n, 0, .5), m2 = .8 * L + rnorm(n, 0, .5),
    m3 = .7 * L + rnorm(n, 0, .5),
    Y = .2 * X + .4 * L + .3 * C + rnorm(n),
    Y2 = rnorm(n)
  )
}

imp_lav <- local({
  d <- gen_lav()
  d$M[1:30] <- NA
  d$m1[31:50] <- NA
  mice::mice(d, m = 2, maxit = 2, method = "norm", printFlag = FALSE, seed = 3)
})

mod_obs <- "M ~ a*X + C\nY ~ b*M + cp*X + C"
mod_lat <- "Mlat =~ m1 + m2 + m3\nMlat ~ a*X + C\nY ~ b*Mlat + cp*X + C"

slav <- function(model = mod_obs, ..., mediator = "M", outcome = "Y") {
  set_md_mediation(imp_lav,
    model = model, treatment = "X", mediator = mediator,
    outcome = outcome, engine = "lavaan", ...
  )
}

test_that("an observed-variable model builds an MDMediationData", {
  md <- slav()
  expect_s3_class(md, "missingmed::MDMediationData")
  expect_identical(md@engine, "lavaan")
  expect_identical(md@model, mod_obs)
  expect_identical(md@outcome, "Y")
  expect_null(md@formula_y)
  expect_null(md@formula_m)
  expect_identical(md@fit_args, list())
})

test_that("a latent-mediator model builds (the mediator is not a data column)", {
  md <- slav(mod_lat, mediator = "Mlat")
  expect_identical(md@mediator, "Mlat")
})

test_that("fit_args is stored on the object", {
  md <- slav(fit_args = list(estimator = "MLR"))
  expect_identical(md@fit_args, list(estimator = "MLR"))
})

test_that("print shows the lavaan model, not formulas", {
  out <- capture.output(print(slav()))
  expect_true(any(grepl("lavaan", out)))
  expect_true(any(grepl("outcome", out)))
})

# -- argument conflicts, refused before any fitting ---------------------------

test_that("formulas with engine = 'lavaan' are refused", {
  expect_error(
    set_md_mediation(imp_lav, Y ~ X + M, M ~ X,
      treatment = "X", mediator = "M", outcome = "Y",
      model = mod_obs, engine = "lavaan"
    ),
    "formula_y.*formula_m.*lavaan|lavaan.*formula"
  )
})

test_that("`model` with engine = 'glm' is refused", {
  expect_error(
    set_md_mediation(imp_lav, Y ~ X + M, M ~ X,
      treatment = "X", mediator = "M", model = mod_obs
    ),
    "`model`.*lavaan"
  )
})

test_that("`outcome` and `fit_args` with engine = 'glm' are refused", {
  expect_error(
    set_md_mediation(imp_lav, Y ~ X + M, M ~ X,
      treatment = "X", mediator = "M", outcome = "Y"
    ),
    "`outcome`.*lavaan"
  )
  expect_error(
    set_md_mediation(imp_lav, Y ~ X + M, M ~ X,
      treatment = "X", mediator = "M", fit_args = list(a = 1)
    ),
    "`fit_args`.*lavaan"
  )
})

test_that("`model` and `outcome` are required for lavaan", {
  expect_error(
    set_md_mediation(imp_lav,
      treatment = "X", mediator = "M", outcome = "Y",
      engine = "lavaan"
    ),
    "`model`"
  )
  expect_error(
    set_md_mediation(imp_lav,
      model = mod_obs, treatment = "X", mediator = "M",
      engine = "lavaan"
    ),
    "`outcome`"
  )
})

test_that("a model with two variables regressed on the mediator needs `outcome`", {
  two <- "M ~ X + C\nY ~ M + X + C\nY2 ~ M + X"
  # Naming either one is fine ...
  expect_s3_class(slav(two, outcome = "Y2"), "missingmed::MDMediationData")
  # ... and a variable that does not regress on the mediator is not an outcome.
  expect_error(slav(two, outcome = "C"), "`outcome`.*regress")
})

# -- structure checks (lavaanify) ---------------------------------------------

test_that("invalid lavaan syntax is refused with the parser's message", {
  expect_error(slav("M ~~~ X"), "not valid lavaan syntax")
})

test_that("missing role variables are named", {
  expect_error(slav("M ~ C\nY ~ M + X + C"), "mediator ~ treatment|`M ~ X`")
  expect_error(slav("M ~ X + C\nY ~ X + C"), "outcome ~ mediator|`Y ~ M`")
  expect_error(slav(mod_obs, outcome = "Z"), "`outcome`.*'Z'")
})

test_that("an observed variable absent from the data is named", {
  expect_error(slav("M ~ X + Q\nY ~ M + X"), "'Q'.*not found in `data`")
})

test_that("treatment, mediator and outcome must be distinct single names", {
  expect_error(slav(outcome = "M"), "different variables")
  expect_error(slav(outcome = c("Y", "Y2")), "`outcome`.*single")
})

test_that("a non-numeric treatment is refused", {
  d <- gen_lav()
  d$M[1:20] <- NA
  d$X <- factor(d$X)
  im <- mice::mice(d, m = 2, maxit = 1, method = "norm", printFlag = FALSE)
  expect_error(
    set_md_mediation(im,
      model = mod_obs, treatment = "X", mediator = "M",
      outcome = "Y", engine = "lavaan"
    ),
    "numeric"
  )
})

test_that("fit_args must be a named list and cannot override the model or data", {
  expect_error(slav(fit_args = list(1)), "`fit_args`.*named")
  expect_error(slav(fit_args = list(model = "x")), "`fit_args`.*model")
  expect_error(slav(fit_args = list(data = 1)), "`fit_args`.*data")
  expect_error(slav(fit_args = "x"), "`fit_args`.*list")
})

test_that("glm construction is unchanged", {
  md <- set_md_mediation(imp_lav, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  expect_identical(md@engine, "glm")
  expect_length(md@model, 0L)
  expect_length(md@outcome, 0L)
})
