# Pre-fit validation in set_md_mediation() and the shared role checks in
# mbco_d4() (.check_roles()).

skip_if_not_installed("mice")

gen_val <- function(n = 200, seed = 9) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rnorm(n)
  M <- .5 * X + .3 * C + rnorm(n)
  Y <- .4 * M + .2 * X + .3 * C + rnorm(n)
  data.frame(X, M, Y, C)
}

imp_val <- function(d = gen_val()) {
  d$M[1:30] <- NA
  mice::mice(d, m = 2, maxit = 2, method = "norm", printFlag = FALSE, seed = 2)
}

imp <- imp_val()

smd <- function(fy, fm, ...) {
  set_md_mediation(imp, fy, fm, treatment = "X", mediator = "M", ...)
}

# ── Roles ───────────────────────────────────────────────────────────────────

test_that("a formula_m that does not model the mediator is refused", {
  # The reproduced silent wrong answer: C ~ X fitted, "a path" = X -> C.
  expect_error(smd(Y ~ X + M + C, C ~ X), "`formula_m`")
  expect_error(smd(Y ~ X + M + C, C ~ X), "'C'.*`mediator` is 'M'")
})

test_that("a transformed mediator response is refused with a column hint", {
  expect_error(smd(Y ~ X + M + C, log(M) ~ X + C), "`formula_m`")
  expect_error(smd(Y ~ X + M + C, log(M) ~ X + C), "transformed column")
})

test_that("the mediator as the outcome is refused", {
  expect_error(smd(M ~ X + M + C, M ~ X + C), "response of `formula_y`")
})

test_that("one-sided formulas and multi-name roles are refused", {
  expect_error(smd(~ X + M + C, M ~ X + C), "`formula_y` must be a two-sided")
  expect_error(
    set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
      treatment = c("X", "C"), mediator = "M"),
    "`treatment` must be a single variable name"
  )
})

test_that("missing main effects are refused, naming the formula", {
  expect_error(smd(Y ~ M + C, M ~ X + C), "`treatment` 'X' must enter `formula_y`")
  expect_error(smd(Y ~ X + C, M ~ X + C), "`mediator` 'M' is not a predictor")
  expect_error(smd(Y ~ X + X:M + C, M ~ X + C),
    "`mediator` 'M' must enter `formula_y` as a main effect")
  expect_error(smd(Y ~ X + M + C, M ~ C), "`treatment` 'X' is not a predictor")
})

test_that("variables absent from the data are refused", {
  expect_error(smd(Y ~ X + M + C + Z, M ~ X + C), "'Z' not found in `data`")
  # A constant from the formula's environment is found, as model.frame() would.
  k <- 2
  expect_error(smd(Y ~ X + M + I(C * k), M ~ X + C), NA)
  expect_error(smd(Y ~ X + M + I(C * pi), M ~ X + C), NA)
  # A missing column that shares its name with a function (stats::C) is still
  # missing.
  d <- gen_val()[c("X", "M", "Y")]
  d$M[1:30] <- NA
  expect_error(
    set_md_mediation(d, Y ~ X + M + C, M ~ X,
      treatment = "X", mediator = "M", method = "ipw"),
    "'C' not found in `data`"
  )
})

test_that("a family given as a string is resolved for the X:M check", {
  expect_error(smd(Y ~ X * M + C, M ~ X + C, family_y = "gaussian"), NA)
  expect_error(smd(Y ~ X * M + C, M ~ X + C, family_m = "poisson"),
    "`family_m` is not")
})

# ── Term grammar ────────────────────────────────────────────────────────────

test_that("products other than X:M are refused, naming the term", {
  expect_error(smd(Y ~ X + M * C, M ~ X + C), "Term `M:C` in `formula_y`",
    fixed = TRUE)
  expect_error(smd(Y ~ X + M + C, M ~ X * C), "Term `X:C` in `formula_m`",
    fixed = TRUE)
  d <- gen_val()
  d$W <- rnorm(nrow(d))
  impw <- imp_val(d)
  expect_error(
    set_md_mediation(impw, Y ~ X * M * W, M ~ X + W,
      treatment = "X", mediator = "M"),
    "Term `X:W`", fixed = TRUE
  )
  expect_error(
    set_md_mediation(impw, Y ~ X * M + X:M:W + W, M ~ X + W,
      treatment = "X", mediator = "M"),
    "Term `X:M:W`", fixed = TRUE
  )
  expect_error(smd(Y ~ X * M + C, M ~ X + C), NA)
  # X:M is outcome-model only.
  expect_error(smd(Y ~ X + M + C, M ~ X + C + X:M), "in `formula_m`")
})

test_that("transforms of the treatment or mediator are refused", {
  expect_error(smd(Y ~ X + M + I(X^2), M ~ X + C), "Term `I(X^2)`",
    fixed = TRUE)
  expect_error(smd(Y ~ X + M + poly(X, 2), M ~ X + C), "Term `poly(X, 2)`",
    fixed = TRUE)
  expect_error(smd(Y ~ X + M + log(M + 10), M ~ X + C), "Term `log(M + 10)`",
    fixed = TRUE)
  expect_error(smd(Y ~ X + M + log(M + 10):X, M ~ X + C), "mbco_d4()",
    fixed = TRUE)
  # Covariate transforms are fine.
  expect_error(smd(Y ~ X + M + I(C^2), M ~ X + C), NA)
})

test_that("offsets involving the treatment or mediator are refused", {
  expect_error(smd(Y ~ X + M + C + offset(M), M ~ X + C),
    "Offset `offset(M)` in `formula_y`", fixed = TRUE)
  expect_error(smd(Y ~ X + M + C, M ~ X + C + offset(.5 * X)),
    "in `formula_m`", fixed = TRUE)
  expect_error(smd(Y ~ X + M + offset(C), M ~ X + C), NA)
})

test_that("X:M, M:X and X * M are accepted and fit identically", {
  e <- function(fy) {
    p <- pool(run(smd(fy, M ~ X + C)))@pooled
    c(p@a_path, p@b_path, p@c_prime)
  }
  ref <- e(Y ~ X * M + C)
  expect_equal(e(Y ~ M:X + X + M + C), ref, tolerance = 1e-12)
  expect_equal(e(Y ~ M * X + C), ref, tolerance = 1e-12)
})

test_that("`Y ~ .` is expanded against the data and accepted", {
  md <- smd(Y ~ ., M ~ X + C)
  expect_true(S7::S7_inherits(md, MDMediationData))
  # The stored formula is the user's, unexpanded.
  expect_identical(md@formula_y, Y ~ .)
  # A dot that pulls in a product is still checked after expansion.
  expect_error(smd(Y ~ .^2, M ~ X + C), "Term `X:C`", fixed = TRUE)
})

test_that("X:M with a non-Gaussian family is refused before fitting", {
  d <- gen_val()
  d$Y <- rbinom(nrow(d), 1, plogis(d$Y))
  impb <- imp_val(d)
  expect_error(
    set_md_mediation(impb, Y ~ X * M + C, M ~ X + C,
      treatment = "X", mediator = "M", family_y = stats::binomial()),
    "`family_y` is not"
  )
  expect_error(
    smd(Y ~ X * M + C, M ~ X + C, family_m = stats::gaussian(link = "log")),
    "`family_m` is not"
  )
  # Without X:M a binary outcome is fine.
  expect_error(
    set_md_mediation(impb, Y ~ X + M + C, M ~ X + C,
      treatment = "X", mediator = "M", family_y = stats::binomial()),
    NA
  )
})

# ── Treatment type ──────────────────────────────────────────────────────────

test_that("a non-numeric treatment is refused; integer and binary pass", {
  d <- gen_val()
  for (x in list(factor(d$X > 0), as.character(d$X > 0), d$X > 0)) {
    dd <- d
    dd$X <- x
    dd$M[1:30] <- NA
    md_ipw <- function() {
      set_md_mediation(dd, Y ~ X + M + C, M ~ X + C,
        treatment = "X", mediator = "M", method = "ipw")
    }
    expect_error(md_ipw(), "must be a numeric column")
    expect_error(md_ipw(), "Recode it to numeric")
  }
  dd <- d
  dd$X <- as.integer(d$X > 0)
  dd$M[1:30] <- NA
  expect_error(
    set_md_mediation(dd, Y ~ X + M + C, M ~ X + C,
      treatment = "X", mediator = "M", method = "ipw"),
    NA
  )
})

# ── mbco_d4() tightenings ───────────────────────────────────────────────────

test_that("mbco_d4() refuses a formula_m that does not model the mediator", {
  il <- mice::complete(imp, "all")
  expect_error(
    mbco_d4(il, Y ~ X + M + C, C ~ X, treatment = "X", mediator = "M"),
    "response of `formula_m`"
  )
})

test_that("mbco_d4() refuses the mediator as the outcome", {
  il <- mice::complete(imp, "all")
  expect_error(
    mbco_d4(il, M ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M"),
    "response of `formula_y`"
  )
})

test_that("mbco_d4() still accepts a transformed mediator and moderated models", {
  il <- lapply(mice::complete(imp, "all"), function(d) {
    d$M <- d$M + 10
    d
  })
  r <- mbco_d4(il, Y ~ X + log(M) + C, log(M) ~ X + C,
    treatment = "X", mediator = "M")
  expect_true(is.finite(r[["D4"]]))
  r <- mbco_d4(il, Y ~ X + M * C, M ~ X * C, treatment = "X", mediator = "M")
  expect_true(is.finite(r[["D4"]]))
})
