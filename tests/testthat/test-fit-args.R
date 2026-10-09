# fit_args for the glm engines, the deprecation of run(...), and `outcome` on
# glm (spec P3, H1).

skip_if_not_installed("mice")

fa_data <- function(n = 150, seed = 11) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rnorm(n)
  M <- .5 * X + .3 * C + rnorm(n)
  Y <- .4 * M + .2 * X + .3 * C + rnorm(n)
  d <- data.frame(X, M, Y, C)
  d$M[1:25] <- NA
  d
}
fa_imp <- local({
  d <- fa_data()
  mice::mice(d, m = 2, maxit = 2, method = "norm", printFlag = FALSE, seed = 3)
})
fa_md <- function(...) {
  set_md_mediation(fa_imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", ...)
}

# Replace the engine call by one that records the names of the extra arguments
# it is given, then fits without them, so the tests do not depend on which
# arguments the installed medfit::fit_mediation() accepts.
record_dots <- function(env) {
  real <- .md_engine_call
  function(object, data, ...) {
    env$seen <- c(env$seen, list(names(list(...))))
    real(object, data)
  }
}

# ── fit_args on glm ─────────────────────────────────────────────────────────

test_that("fit_args is stored on a glm object and forwarded on every fit", {
  md <- fa_md(fit_args = list(m_star = 0))
  expect_identical(md@fit_args, list(m_star = 0))
  env <- new.env()
  local_mocked_bindings(.md_engine_call = record_dots(env))
  expect_no_warning(fit <- run(md))
  expect_length(env$seen, 2L)
  expect_true(all(vapply(env$seen, function(n) "m_star" %in% n, logical(1))))
  expect_equal(fit@m, 2L)
})

test_that("without fit_args nothing extra is forwarded", {
  env <- new.env()
  local_mocked_bindings(.md_engine_call = record_dots(env))
  run(fa_md())
  expect_true(all(lengths(env$seen) == 0L))
})

test_that("fit_args must be a named list that does not restate set_md_mediation()", {
  expect_error(fa_md(fit_args = list(1)), "`fit_args` must be a named list")
  expect_error(fa_md(fit_args = "x"), "`fit_args` must be a list")
  expect_error(fa_md(fit_args = list(data = 1)), "`fit_args` cannot set `data`")
  expect_error(fa_md(fit_args = list(family_y = 1, engine = "x")),
    "cannot set `family_y`, `engine`")
})

test_that("the IPW path forwards fit_args and refuses weights/se_type in them", {
  d <- fa_data()
  ipw_md <- function(...) {
    set_md_mediation(d, Y ~ X + M + C, M ~ X + C, treatment = "X",
      mediator = "M", method = "ipw", ...)
  }
  env <- new.env()
  local_mocked_bindings(.md_engine_call = record_dots(env))
  run(ipw_md(fit_args = list(m_star = 0)))
  expect_true(all(c("m_star", "weights", "se_type") %in% env$seen[[1]]))
  expect_error(run(ipw_md(fit_args = list(weights = 1))),
    "`weights` cannot be passed as an extra argument")
})

# ── run(...) deprecation ────────────────────────────────────────────────────

test_that("run(...) still forwards, with a deprecation warning naming fit_args", {
  env <- new.env()
  local_mocked_bindings(.md_engine_call = record_dots(env))
  expect_warning(run(fa_md(), m_star = 0), class = "md_dots_deprecated")
  expect_warning(run(fa_md(), m_star = 0), "`m_star` with `fit_args`")
  expect_true(all(vapply(env$seen, function(n) "m_star" %in% n, logical(1))))
})

test_that("run(...) may not repeat a name already in fit_args", {
  md <- fa_md(fit_args = list(m_star = 0))
  expect_error(run(md, m_star = 1), "`run\\(\\)` repeats `m_star`, already set")
})

test_that("run(...) extras must be named and cannot restate set_md_mediation()", {
  expect_error(suppressWarnings(run(fa_md(), 1)), "must be named")
  expect_error(suppressWarnings(run(fa_md(), family_y = 1)),
    "`family_y` cannot be passed")
})

test_that("fit_args and run(...) extras combine", {
  env <- new.env()
  local_mocked_bindings(.md_engine_call = record_dots(env))
  suppressWarnings(run(fa_md(fit_args = list(m_star = 0)), engine_args = list()))
  expect_true(all(vapply(env$seen,
    function(n) all(c("m_star", "engine_args") %in% n), logical(1))))
})

# ── sensitivity_mnar() ──────────────────────────────────────────────────────

test_that("sensitivity_mnar() reuses the stored fit_args on every rung", {
  skip_if_not_installed("RMediation")
  env <- new.env()
  local_mocked_bindings(.md_engine_call = record_dots(env))
  md <- fa_md(fit_args = list(m_star = 0))
  expect_no_warning(sensitivity_mnar(md, delta = c(0, -0.5), n.mc = 500))
  expect_gte(length(env$seen), 4L) # 2 rungs x 2 imputations
  expect_true(all(vapply(env$seen, function(n) "m_star" %in% n, logical(1))))
})

test_that("sensitivity_mnar(...) warns once, not once per rung", {
  skip_if_not_installed("RMediation")
  local_mocked_bindings(.md_engine_call = record_dots(new.env()))
  warns <- character()
  withCallingHandlers(
    sensitivity_mnar(fa_md(), delta = c(0, -0.5, -1), n.mc = 500, m_star = 0),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  dep <- grep("deprecated", warns, value = TRUE)
  expect_length(dep, 1L)
  expect_match(dep, "`sensitivity_mnar\\(\\)`")
})

# ── outcome on glm ──────────────────────────────────────────────────────────

test_that("outcome is optional on glm and must match the response when given", {
  expect_no_error(fa_md(outcome = "Y"))
  expect_error(fa_md(outcome = "M"), "`outcome` is 'M' but the response of `formula_y` is 'Y'")
  expect_error(fa_md(outcome = c("Y", "M")), "`outcome` is")
  expect_error(
    set_md_mediation(fa_imp, Y ~ X + M + C, M ~ X + C, treatment = "X",
      mediator = "M", model = "Y ~ M"),
    "`model` is only used with engine = \"lavaan\""
  )
})

# ── lavaan unchanged ────────────────────────────────────────────────────────

test_that("run(...) still errors for lavaan", {
  skip_if_not_installed("lavaan")
  d <- fa_data()
  imp <- mice::mice(d, m = 2, maxit = 1, method = "norm", printFlag = FALSE, seed = 1)
  md <- set_md_mediation(imp, model = "M ~ X + C\nY ~ M + X + C", outcome = "Y",
    treatment = "X", mediator = "M", engine = "lavaan")
  expect_error(run(md, estimator = "MLR"), "takes no extra arguments for engine = \"lavaan\"")
})
