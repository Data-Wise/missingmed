# sensitivity_mnar(on_error =): keep the rungs that worked
# (SPEC-sensitivity-on-error-2026-10-09.md).

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

gen_oe <- function(n = 200, seed = 4) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.6 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.5 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < plogis(-1.2 + 0.5 * X + 0.5 * C)] <- NA
  d
}
md_oe <- function(m = 3, seed = 99) {
  d <- gen_oe() # materialize before mice() sets its seed (see test-sensitivity-mnar.R)
  imp <- mice::mice(d, m = m, maxit = 3, printFlag = FALSE, seed = seed)
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M")
}

# Wrap run() so a rung fails when its imputed data carry a delta in `bad`. The
# rung's delta is recovered from the mean of the first completed imputation:
# the shift moves every imputed M by delta, so the mean is monotone in delta.
# Thresholds are computed from real re-imputations, not hard-coded.
local_run_fails_at <- function(md, bad, how = c("error", "warning"), env = parent.frame()) {
  how <- match.arg(how)
  real <- run
  seed <- 99
  fail_means <- vapply(bad, function(dl) {
    mean(mice::complete(missingmed:::.mnar_reimpute(md@data, data.frame(M = dl), seed), 1)$M)
  }, numeric(1))
  stub <- function(object, ...) {
    mu <- mean(mice::complete(object@data, 1)$M)
    if (any(abs(mu - fail_means) < 1e-9)) {
      if (how == "error") stop("planted failure", call. = FALSE) else warning("planted warning", call. = FALSE)
    }
    real(object, ...)
  }
  testthat::local_mocked_bindings(run = stub, .package = "missingmed", .env = env)
}

test_that("default on_error = 'stop' aborts at the failing rung, naming it", {
  md <- md_oe()
  local_run_fails_at(md, bad = 2)
  expect_error(
    suppressMessages(sensitivity_mnar(md, target = "M", delta = c(-1, 0, 2), type = "mbco")),
    "rung 3 of 3 \\(M = 2\\).*planted failure"
  )
})

test_that("on_error = 'continue' keeps successful rungs, bit-identical to 'stop'", {
  md <- md_oe()
  ref <- tidy(suppressMessages(
    sensitivity_mnar(md, target = "M", delta = c(-1, 0, 1), type = "mbco")
  ))
  local_run_fails_at(md, bad = 2)
  expect_warning(
    res <- suppressMessages(sensitivity_mnar(md,
      target = "M", delta = c(-1, 0, 1, 2), type = "mbco", on_error = "continue"
    )),
    "1 of 4 rung\\(s\\) failed.*rung 4"
  )
  expect_equal(res@failed, c(NA, NA, NA, "planted failure"))
  expect_null(res@rungs[[4]])
  tb <- tidy(res)
  expect_true("error" %in% names(tb))
  expect_equal(tb$error, c(NA, NA, NA, "planted failure"))
  expect_true(is.na(tb$p_value[4]))
  expect_identical(as.data.frame(tb[1:3, names(ref)]), as.data.frame(ref))
})

test_that("a clean 'continue' run has no failed column and no warning", {
  md <- md_oe()
  expect_no_warning(
    res <- suppressMessages(sensitivity_mnar(md,
      target = "M", delta = c(0, 1), type = "mbco", on_error = "continue"
    ))
  )
  expect_false("error" %in% names(tidy(res)))
  expect_true(all(is.na(res@failed)) || !length(res@failed))
})

test_that("'continue' works for type = 'mc' too", {
  md <- md_oe()
  local_run_fails_at(md, bad = 1)
  expect_warning(
    res <- suppressMessages(sensitivity_mnar(md,
      target = "M", delta = c(0, 1, 2), type = "mc", n.mc = 2000, on_error = "continue"
    )),
    "1 of 3 rung\\(s\\) failed"
  )
  tb <- tidy(res)
  expect_true(is.na(tb$estimate[2]))
  expect_false(anyNA(tb$estimate[c(1, 3)]))
})

test_that("every rung failing is an error under 'continue'", {
  md <- md_oe()
  local_run_fails_at(md, bad = c(0, 1))
  expect_error(
    suppressMessages(sensitivity_mnar(md,
      target = "M", delta = c(0, 1), type = "mbco", on_error = "continue"
    )),
    "all 2 rung\\(s\\) failed.*planted failure"
  )
})

test_that("only errors are caught: a warning inside a rung is not a failure", {
  md <- md_oe()
  local_run_fails_at(md, bad = 1, how = "warning")
  res <- NULL
  expect_warning(
    res <- suppressMessages(sensitivity_mnar(md,
      target = "M", delta = c(0, 1), type = "mbco", on_error = "continue"
    )),
    "planted warning"
  )
  expect_false(anyNA(tidy(res)$p_value))
  expect_true(!length(res@failed) || all(is.na(res@failed)))
})

test_that("on_error is validated", {
  md <- md_oe()
  expect_error(
    sensitivity_mnar(md, target = "M", delta = 0, on_error = "ignore"),
    "should be one of"
  )
})

test_that("print and summary work when rung 1 failed and never interpolate a gap", {
  md <- md_oe()
  local_run_fails_at(md, bad = 0)
  res <- NULL
  suppressWarnings(res <- suppressMessages(sensitivity_mnar(md,
    target = "M", delta = c(0, 0.5, 1), type = "mbco", on_error = "continue"
  )))
  expect_output(print(res), "failed rungs: 1")
  s <- summary(res)
  expect_equal(s$na_rungs, 1L)
  # The failed rung sits at MAR (delta = 0): the tipping point is unknown, not
  # read off the neighbors.
  expect_true(s$undetermined)
  expect_null(s$tipping)
})

test_that("the validator rejects a NULL rung that is not recorded as failed", {
  md <- md_oe()
  res <- suppressMessages(sensitivity_mnar(md, target = "M", delta = c(0, 1), type = "mbco"))
  rungs <- res@rungs
  rungs[2] <- list(NULL)
  expect_error(
    S7::set_props(res, rungs = rungs),
    "failed"
  )
  expect_error(
    S7::set_props(res, rungs = rungs, failed = c(NA, "x")),
    NA
  )
})
