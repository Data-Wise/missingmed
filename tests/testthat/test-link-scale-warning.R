# infer(type = "mc") warns when a*b is on a non-identity link scale (#86).
# The warning is once per session; "verbose" makes every call warn here.

make_link_data <- function(seed = 1, n = 300) {
  set.seed(seed)
  d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
  d$M <- rbinom(n, 1, plogis(-0.2 + 0.6 * d$X + 0.2 * d$C))
  d$Y <- 0.4 * d$M + 0.2 * d$X + 0.2 * d$C + rnorm(n)
  d$K <- rpois(n, exp(0.2 + 0.3 * d$M + 0.2 * d$X))
  d$Y[sample(n, 40)] <- NA
  d
}

link_fit <- function(family_m = gaussian(), family_y = gaussian(), y = "Y",
                     method = "mi", seed = 1) {
  d <- make_link_data(seed)
  if (y == "K") d$K[is.na(d$Y)] <- NA
  dat <- if (method == "mi") mice::mice(d, m = 3, printFlag = FALSE, seed = seed) else d
  fy <- stats::as.formula(paste(y, "~ X + M + C"))
  run(set_md_mediation(dat, fy, M ~ X + C,
    treatment = "X", mediator = "M",
    family_m = family_m, family_y = family_y, method = method
  ))
}

bin_fit <- suppressWarnings(link_fit(family_m = binomial()))

test_that("a binomial mediator warns on infer(type = 'mc'), naming the link", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  w <- expect_warning(infer(bin_fit, type = "mc", n.mc = 1e3),
    class = "missingmed_link_scale_warning")
  expect_match(conditionMessage(w), "mediator model link = \"logit\"", fixed = TRUE)
  expect_match(conditionMessage(w), "Binary mediator or outcome?", fixed = TRUE)
  expect_no_match(conditionMessage(w), "outcome model link")
})

test_that("the pooled MDMediationResult path warns too", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  expect_warning(infer(pool(bin_fit), type = "mc", n.mc = 1e3),
    class = "missingmed_link_scale_warning")
})

test_that("a poisson outcome warns, naming the outcome's log link", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  f <- suppressWarnings(link_fit(family_y = poisson(), y = "K"))
  w <- expect_warning(infer(f, type = "mc", n.mc = 1e3),
    class = "missingmed_link_scale_warning")
  expect_match(conditionMessage(w), "outcome model link = \"log\"", fixed = TRUE)
})

test_that("both links non-identity names both", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  f <- suppressWarnings(link_fit(family_m = binomial(), family_y = poisson(), y = "K"))
  w <- expect_warning(infer(f, type = "mc", n.mc = 1e3),
    class = "missingmed_link_scale_warning")
  expect_match(conditionMessage(w), "mediator model link = \"logit\", outcome model link = \"log\"",
    fixed = TRUE)
})

test_that("IPW with a binomial mediator warns", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  f <- suppressWarnings(link_fit(family_m = binomial(), method = "ipw"))
  expect_warning(infer(f, type = "mc", n.mc = 1e3),
    class = "missingmed_link_scale_warning")
})

test_that("identity links do not warn", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  f <- link_fit()
  expect_no_warning(infer(f, type = "mc", n.mc = 1e3),
    class = "missingmed_link_scale_warning")
})

test_that("the MBCO test does not warn about the scale", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  expect_no_warning(suppressMessages(infer(bin_fit, type = "mbco")),
    class = "missingmed_link_scale_warning")
})

test_that("the warning is throttled outside verbose mode", {
  rlang::local_options(rlib_warning_verbosity = "quiet")
  expect_no_warning(infer(bin_fit, type = "mc", n.mc = 1e3),
    class = "missingmed_link_scale_warning")
})

test_that("input errors still come before the warning", {
  rlang::local_options(rlib_warning_verbosity = "verbose")
  expect_error(infer(bin_fit, type = "mc", level = 2), "`level` must be")
})
