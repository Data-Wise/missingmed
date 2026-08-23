# Non-gaussian families through the S7 pipeline (engine = "glm").
#
# missingmed forwards engine/family_y/family_m straight to
# medfit::fit_mediation(), whose default engine IS "glm", so GLM support has
# been plumbed since the S7 rewrite -- but nothing exercised it. These tests
# pin the pass-through for a binary mediator, a binary outcome and a count
# outcome, under both estimators.
#
# SCALE: for a non-identity link, a and b are link-scale coefficients, so the
# product a*b and its Monte-Carlo CI are on the link scale too -- log-odds for
# binomial, log-rate for poisson. They are NOT risk differences or odds ratios,
# and exponentiating a*b does not produce one. See vignette("technical").

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

# Data generators. Each keeps the mediator on the causal path to the outcome --
# a generator where Y ignores M yields a true indirect effect of 0 and would
# make the "CI excludes zero" assertions below meaningless.
gen_binary_mediator <- function(n) {
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- rbinom(n, 1, plogis(-0.2 + 1.2 * X + 0.3 * C))
  Y <- 0.2 * X + 1.0 * M + 0.3 * C + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C = C)
}
gen_binary_outcome <- function(n) {
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.9 * X + 0.3 * C + rnorm(n)
  Y <- rbinom(n, 1, plogis(-0.1 + 0.2 * X + 1.0 * M + 0.3 * C))
  data.frame(X = X, M = M, Y = Y, C = C)
}
gen_count_outcome <- function(n) {
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.9 * X + 0.3 * C + rnorm(n)
  Y <- rpois(n, exp(0.2 + 0.15 * X + 0.45 * M + 0.1 * C))
  data.frame(X = X, M = M, Y = Y, C = C)
}
impose_mar <- function(d) {
  d$M[runif(nrow(d)) < plogis(-1.4 + 0.5 * d$X + 0.5 * d$C)] <- NA
  d$Y[runif(nrow(d)) < plogis(-1.6 + 0.5 * d$X + 0.5 * d$C)] <- NA
  d
}

mi_ci <- function(gen, family_m = stats::gaussian(), family_y = stats::gaussian(),
                  n = 600, m = 4, seed = 7) {
  set.seed(seed)
  imp <- mice::mice(impose_mar(gen(n)), m = m, printFlag = FALSE, seed = seed)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M",
    family_m = family_m, family_y = family_y
  )
  infer(pool(run(md)), type = "mc", n.mc = 5e3)
}

expect_sane_ci <- function(ci) {
  expect_true(is.numeric(ci$CI) && length(ci$CI) == 2)
  expect_true(all(is.finite(ci$CI)))
  expect_lt(ci$CI[1], ci$CI[2])
}

# ── MI ──────────────────────────────────────────────────────────────────────

test_that("MI: binomial mediator runs and recovers a positive indirect effect", {
  ci <- mi_ci(gen_binary_mediator, family_m = stats::binomial())
  expect_sane_ci(ci)
  expect_gt(ci$CI[1], 0) # true a and b are both positive
})

test_that("MI: binomial outcome runs and recovers a positive indirect effect", {
  ci <- mi_ci(gen_binary_outcome, family_y = stats::binomial())
  expect_sane_ci(ci)
  expect_gt(ci$CI[1], 0)
})

test_that("MI: poisson outcome runs and recovers a positive indirect effect", {
  ci <- mi_ci(gen_count_outcome, family_y = stats::poisson())
  expect_sane_ci(ci)
  expect_gt(ci$CI[1], 0)
})

test_that("MI: a non-gaussian family still pools to a named MediationData", {
  set.seed(31)
  imp <- mice::mice(impose_mar(gen_binary_outcome(400)),
    m = 3, printFlag = FALSE, seed = 31
  )
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_y = stats::binomial()
  )
  res <- pool(run(md))
  expect_s7_class(res@pooled, medfit::MediationData)
  expect_true(all(c("a", "b", "c_prime") %in% names(res@pooled@estimates)))
  expect_true(all(c("a", "b") %in% rownames(res@pooled@vcov)))
})

# ── IPW ─────────────────────────────────────────────────────────────────────

test_that("IPW: binomial outcome runs with sandwich SEs", {
  set.seed(21)
  md <- set_md_mediation(impose_mar(gen_binary_outcome(800)),
    Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw",
    family_y = stats::binomial(), se_type = "sandwich"
  )
  ci <- suppressWarnings(infer(pool(run(md)), type = "mc", n.mc = 5e3))
  expect_sane_ci(ci)
  expect_gt(ci$CI[1], 0)
})

test_that("IPW: binomial mediator runs with sandwich SEs", {
  set.seed(22)
  md <- set_md_mediation(impose_mar(gen_binary_mediator(800)),
    Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw",
    family_m = stats::binomial(), se_type = "sandwich"
  )
  ci <- suppressWarnings(infer(pool(run(md)), type = "mc", n.mc = 5e3))
  expect_sane_ci(ci)
  expect_gt(ci$CI[1], 0)
})

test_that("IPW + binomial warns about non-integer successes (known, benign)", {
  # stats::glm() warns whenever a binomial fit gets non-integer prior weights.
  # Here the weights are inverse-probability sampling weights, not trial
  # counts, so the warning is a false alarm -- the weighted score equations are
  # exactly what IPW asks for. Pinned deliberately: if this is ever suppressed
  # in .ipw_run(), this test should fail and force the decision to be explicit.
  set.seed(23)
  md <- set_md_mediation(impose_mar(gen_binary_outcome(400)),
    Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw",
    family_y = stats::binomial(), se_type = "sandwich"
  )
  expect_warning(run(md), "non-integer")
})

# ── MBCO ────────────────────────────────────────────────────────────────────

test_that("MBCO: D4 works with a binomial mediator", {
  # D4 parity with the research prototype was only ever checked gaussian; this
  # is a sanity check on the non-gaussian path, not a parity check.
  set.seed(3)
  imp <- mice::mice(impose_mar(gen_binary_mediator(600)),
    m = 4, printFlag = FALSE, seed = 3
  )
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_m = stats::binomial()
  )
  out <- infer(run(md), type = "mbco")
  expect_named(out, c("D4", "p", "r4", "nu", "d_S"))
  expect_true(all(is.finite(out)))
  expect_gt(out[["D4"]], 0)
  expect_gte(out[["p"]], 0)
  expect_lte(out[["p"]], 1)
  expect_lt(out[["p"]], 0.05) # strong mediation in this DGP
})
