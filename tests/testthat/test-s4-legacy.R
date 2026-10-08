# Edge-case and end-to-end tests for the deprecated S4 API:
# set_sem() / run_sem() / pool_sem(), the SemImputedData / SemResults /
# PooledSEMResults classes, and the helpers fit_model(), lav_mice(),
# mx_mice(), is_fit(), is_pd(), is_lav_syntax(), is_valid_lav_syntax(),
# n_imp(). Kept in ONE file so it can be deleted with the S4 API (0.6.0).

# ---- helpers ---------------------------------------------------------------

s4_data <- function(n = 120, seed = 7) {
  set.seed(seed)
  x <- rnorm(n)
  m <- 0.4 * x + rnorm(n)
  y <- 0.3 * m + 0.2 * x + rnorm(n)
  d <- data.frame(x = x, m = m, y = y)
  d$m[sample(n, 15)] <- NA
  d$y[sample(n, 12)] <- NA
  d
}

s4_mids <- function(m = 2) {
  mice::mice(s4_data(), m = m, maxit = 2, seed = 11, printFlag = FALSE)
}

s4_model <- "m ~ a*x\n y ~ b*m + x"

# Run `expr`, muffling and recording every warning; returns value + messages.
s4_collect <- function(expr) {
  warns <- character(0)
  value <- withCallingHandlers(expr, warning = function(w) {
    warns <<- c(warns, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  list(value = value, warnings = warns)
}

s4_mx_model <- function() {
  OpenMx::mxModel("med",
    type = "RAM", manifestVars = c("x", "m", "y"),
    OpenMx::mxPath(from = "x", to = "m", labels = "a"),
    OpenMx::mxPath(from = "m", to = "y", labels = "b"),
    OpenMx::mxPath(from = "x", to = "y", labels = "cp"),
    OpenMx::mxPath(from = c("x", "m", "y"), arrows = 2, values = 1),
    OpenMx::mxPath(from = "one", to = c("x", "m", "y"))
  )
}

# ---- is_pd -----------------------------------------------------------------

test_that("is_pd() separates PD, singular, and non-square matrices", {
  expect_true(is_pd(matrix(c(2, 1, 1, 2), 2)))
  expect_true(is_pd(matrix(c(2, 1, 1, 2), 2,
    dimnames = list(c("a", "b"), c("a", "b"))
  )))
  expect_false(is_pd(matrix(c(1, 2, 2, 4), 2), quiet = TRUE))
  expect_false(is_pd(matrix(c(1, 2, 2, 1), 2), quiet = TRUE))
  expect_false(is_pd(-diag(2), quiet = TRUE))
  expect_false(is_pd(matrix(1:6, 2), quiet = TRUE))
})

test_that("is_pd() returns FALSE for a non-symmetric matrix", {
  # chol() reads only the upper triangle, which here is PD; dev said TRUE.
  asym <- matrix(c(2, 9, 0, 2), 2)
  expect_false(is_pd(asym, quiet = TRUE))
  expect_output(res <- is_pd(asym), "not symmetric")
  expect_false(res)
})

test_that("is_pd() quiet = TRUE prints nothing", {
  expect_silent(is_pd(matrix(c(1, 2, 2, 4), 2), quiet = TRUE))
})

test_that("is_pd() has no method for non-matrix input", {
  expect_error(is_pd(c(1, 2)), "unable to find an inherited method")
  expect_error(is_pd(data.frame(a = 1:2)), "unable to find an inherited method")
})

# ---- is_lav_syntax / is_valid_lav_syntax -----------------------------------

test_that("is_lav_syntax() accepts valid and rejects invalid syntax", {
  skip_if_not_installed("lavaan")
  expect_true(is_lav_syntax(s4_model))
  expect_false(is_lav_syntax("y ~~~ (", quiet = TRUE))
  expect_false(is_lav_syntax("", quiet = TRUE))
  expect_false(is_lav_syntax(5, quiet = TRUE))
  expect_output(is_lav_syntax(5), "must be a character string")
})

test_that("is_lav_syntax(quiet = TRUE) does not leak the parser error", {
  skip_if_not_installed("lavaan")
  expect_silent(res <- is_lav_syntax("y ~~~ (", quiet = TRUE))
  expect_false(res)
})

test_that("is_valid_lav_syntax() checks the model against the data", {
  skip_if_not_installed("lavaan")
  d <- s4_data()
  expect_true(is_valid_lav_syntax(s4_model, d))
  expect_true(is_valid_lav_syntax(s4_model))
  expect_false(is_valid_lav_syntax("y ~ zz", d))
  expect_false(is_valid_lav_syntax("y ~~~ (", d))
  expect_false(is_valid_lav_syntax(5, d))
  expect_error(
    is_valid_lav_syntax(s4_model, as.matrix(d)),
    "'data' must be a data frame"
  )
})

# ---- is_fit / n_imp --------------------------------------------------------

test_that("is_fit() reports whether a model was fitted", {
  skip_if_not_installed("lavaan")
  d <- s4_data()
  expect_true(is_fit(lavaan::sem(s4_model, data = d)))
  expect_false(is_fit(lavaan::sem(s4_model, data = d, do.fit = FALSE)))
  expect_false(is_fit(lm(y ~ x, data = d)))
  expect_false(is_fit(NULL))
  expect_false(is_fit("m ~ x"))
})

test_that("is_fit() means 'fitted', not 'converged'", {
  skip_if_not_installed("lavaan")
  set.seed(3)
  f <- rnorm(60)
  cf <- data.frame(
    y1 = f + rnorm(60), y2 = 0.8 * f + rnorm(60),
    y3 = 0.6 * f + rnorm(60), y4 = 0.5 * f + rnorm(60)
  )
  nc <- suppressWarnings(
    lavaan::cfa("F =~ y1 + y2 + y3 + y4", data = cf, control = list(iter.max = 2))
  )
  expect_false(lavaan::lavInspect(nc, "converged"))
  expect_true(is_fit(nc))
})

test_that("n_imp() returns m for a mids and errors clearly otherwise", {
  expect_equal(n_imp(s4_mids(m = 2)), 2)
  expect_error(n_imp(s4_data()), "not a 'mids' object \\(it has class 'data.frame'\\)")
  expect_error(n_imp(NULL), "not a 'mids' object")
})

# ---- engine/model-type check (fit_model, model_type) -----------------------

test_that("fit_model() fits syntax and unfitted lavaan objects", {
  skip_if_not_installed("lavaan")
  d <- s4_data()
  fit_s <- fit_model(s4_model, d)
  expect_s4_class(fit_s, "lavaan")
  expect_true(is_fit(fit_s))
  unfit <- lavaan::sem(s4_model, data = d, do.fit = FALSE)
  expect_true(is_fit(fit_model(unfit, d)))
  fitted <- lavaan::sem(s4_model, data = d)
  expect_identical(fit_model(fitted, d), fitted)
})

test_that("fit_model() lists the accepted model types for anything else", {
  d <- s4_data()
  expect_error(
    fit_model(5, d),
    "Unsupported model of class 'numeric'.*lavaan' model syntax string.*'lavaan' object.*'MxModel'"
  )
  expect_error(fit_model(list(), d), "Unsupported model of class 'list'")
  err <- tryCatch(fit_model(5, d), error = function(e) e)
  expect_null(conditionCall(err))
})

test_that("fit_model() rejects invalid syntax without parser noise", {
  skip_if_not_installed("lavaan")
  d <- s4_data()
  expect_silent(err <- tryCatch(fit_model("y ~~~ (", d), error = function(e) e))
  expect_match(conditionMessage(err), "not a valid 'lavaan' syntax")
  expect_null(conditionCall(err))
})

test_that("fit_model() validates data and passes lavaan's own errors through", {
  skip_if_not_installed("lavaan")
  d <- s4_data()
  expect_error(fit_model(s4_model, as.matrix(d)), "The data must be a data frame")
  expect_error(fit_model(s4_model, list(x = 1)), "The data must be a data frame")
  expect_error(fit_model("y ~ zz", d), "not found in the\\s+dataset: zz")
})

# ---- per-imputation error/warning handling ---------------------------------

test_that(".fit_each_imputation() rethrows naming engine and imputation", {
  expect_error(
    .fit_each_imputation("lavaan", 3, function(i) {
      if (i == 2) stop("boom at two") else i
    }),
    "^lavaan failed on imputation 2: boom at two$"
  )
})

test_that(".fit_each_imputation() collects warnings into one", {
  out <- s4_collect(.fit_each_imputation("OpenMx", 3, function(i) {
    if (i != 2) warning("status RED\n   at  optimum")
    i
  }))
  expect_identical(out$value, list(1L, 2L, 3L))
  expect_length(out$warnings, 1)
  expect_match(
    out$warnings,
    "^OpenMx issued warnings on imputation\\(s\\) 1, 3 of 3: status RED at optimum$"
  )
})

test_that(".fit_each_imputation() is silent and unchanged on clean fits", {
  expect_silent(res <- .fit_each_imputation("lavaan", 2, function(i) i * 10))
  expect_identical(res, list(10, 20))
})

# ---- lav_mice --------------------------------------------------------------

test_that("lav_mice() fits each imputation exactly as lavaan::sem() does", {
  skip_if_not_installed("lavaan")
  imp <- s4_mids(m = 2)
  fits <- lav_mice(s4_model, imp)
  expect_length(fits, 2)
  for (i in 1:2) {
    direct <- lavaan::sem(s4_model, data = mice::complete(imp, i))
    expect_identical(lavaan::coef(fits[[i]]), lavaan::coef(direct))
    expect_identical(vcov_lav(fits[[i]]), vcov_lav(direct))
  }
  # a lavaan object is refitted (via update()) to each imputation; update()
  # re-evaluates the stored call, so build it with the literal model string
  obj <- do.call(lavaan::sem, list(model = s4_model, data = s4_data()))
  fits_obj <- lav_mice(obj, imp)
  expect_equal(lavaan::coef(fits_obj[[1]]), lavaan::coef(fits[[1]]))
})

test_that("lav_mice() validates its inputs", {
  skip_if_not_installed("lavaan")
  imp <- s4_mids(m = 2)
  expect_error(lav_mice(s4_model, s4_data()), "'mids' must be a 'mids' object")
  expect_error(lav_mice(imp, s4_model), "'mids' must be a 'mids' object")
  expect_error(lav_mice("y ~~~ (", imp), "not a valid lavaan model syntax")
  expect_error(lav_mice("y ~ zz", imp), "not a valid lavaan model syntax")
  expect_error(lav_mice(5, imp), "not a valid lavaan model syntax")
})

test_that("lav_mice() names the engine and imputation on a lavaan error", {
  skip_if_not_installed("lavaan")
  imp <- s4_mids(m = 2)
  expect_error(
    lav_mice(s4_model, imp, estimator = "bogus"),
    "lavaan failed on imputation 1: .*invalid value in estimator option"
  )
})

test_that("lav_mice() reports non-convergence once, naming imputations", {
  skip_if_not_installed("lavaan")
  set.seed(3)
  f <- rnorm(60)
  cf <- data.frame(
    y1 = f + rnorm(60), y2 = 0.8 * f + rnorm(60),
    y3 = 0.6 * f + rnorm(60), y4 = 0.5 * f + rnorm(60)
  )
  cf$y4[sample(60, 8)] <- NA
  impc <- mice::mice(cf, m = 2, maxit = 2, seed = 5, printFlag = FALSE)
  out <- s4_collect(lav_mice("F =~ y1 + y2 + y3 + y4", impc,
    control = list(iter.max = 2)
  ))
  expect_length(out$value, 2)
  expect_length(out$warnings, 1)
  expect_match(
    out$warnings,
    "^lavaan issued warnings on imputation\\(s\\) 1, 2 of 2: .*NOT been found"
  )
})

# ---- set_sem argument checks ------------------------------------------------

test_that("set_sem() rejects bad conf_int / conf_level clearly", {
  skip_if_not_installed("lavaan")
  imp <- s4_mids(m = 2)
  expect_warning(
    expect_error(set_sem(imp, s4_model, conf_int = NA), "'conf_int' must be a single logical"),
    "deprecated"
  )
  expect_warning(
    expect_error(set_sem(imp, s4_model, conf_int = "yes"), "'conf_int' must be a single logical"),
    "deprecated"
  )
  expect_warning(
    expect_error(
      set_sem(imp, s4_model, conf_int = TRUE, conf_level = NA_real_),
      "'conf_level' must be a single numeric value between 0 and 1"
    ),
    "deprecated"
  )
  expect_warning(
    expect_error(
      set_sem(imp, s4_model, conf_int = TRUE, conf_level = 1),
      "'conf_level' must be a single numeric value between 0 and 1"
    ),
    "deprecated"
  )
  # conf_int = FALSE: the class validity check still bounds conf_level
  expect_warning(
    expect_error(set_sem(imp, s4_model, conf_level = 1.5), "'conf_level' must be"),
    "deprecated"
  )
})

test_that("set_sem() rejects unsupported models and non-mids data", {
  skip_if_not_installed("lavaan")
  imp <- s4_mids(m = 2)
  expect_warning(
    expect_error(set_sem(imp, 5), "Unsupported model of class 'numeric'"),
    "deprecated"
  )
  expect_warning(
    expect_error(set_sem(imp, "y ~~~ ("), "not a valid 'lavaan' syntax"),
    "deprecated"
  )
  expect_warning(
    expect_error(set_sem(imp), "Argument 'model' is missing"),
    "deprecated"
  )
  expect_error(set_sem(s4_data(), s4_model), "unable to find an inherited method")
})

# ---- classes ---------------------------------------------------------------

test_that("SemResults validity rejects an unknown method", {
  expect_error(
    SemResults(results = list(1), cov_df = list(1), method = "Mplus"),
    "method must be either 'lavaan' or 'OpenMx'"
  )
})

test_that("PooledSEMResults requires the base tidy_table columns", {
  # dev checked only 'term' (ifelse() truncated the column list to length 1)
  expect_error(
    PooledSEMResults(
      tidy_table = data.frame(term = "a"), cov_total = diag(1),
      cov_between = diag(1), cov_within = diag(1), method = "lavaan",
      conf_int = FALSE, conf_level = 0.95
    ),
    "Missing required columns in tidy_table: estimate, std_error, p_value"
  )
  ok <- PooledSEMResults(
    tidy_table = data.frame(term = "a", estimate = 1, std_error = 1, p_value = 0.5),
    cov_total = diag(1), cov_between = diag(1), cov_within = diag(1),
    method = "lavaan", conf_int = TRUE, conf_level = 0.95
  )
  expect_s4_class(ok, "PooledSEMResults")
})

test_that("PooledSEMResults warns (without console noise) on a singular matrix", {
  out <- s4_collect(printed <- capture.output(
    obj <- PooledSEMResults(
      tidy_table = data.frame(term = "a", estimate = 1, std_error = 1, p_value = 0.5),
      cov_total = diag(2), cov_between = matrix(1, 2, 2), cov_within = diag(2),
      method = "lavaan", conf_int = FALSE, conf_level = 0.95
    )
  ))
  expect_s4_class(obj, "PooledSEMResults")
  expect_identical(printed, character(0))
  expect_identical(out$warnings, "cov_between must be a symmetric positive definite matrix.")
})

# ---- end-to-end: lavaan ----------------------------------------------------

test_that("set_sem() -> run_sem() -> pool_sem() works and applies Rubin's rules (lavaan)", {
  skip_if_not_installed("lavaan")
  imp <- s4_mids(m = 2)
  m <- 2

  sd <- s4_collect(set_sem(imp, s4_model))
  expect_true(any(grepl("set_sem\\(\\) is deprecated", sd$warnings)))
  expect_s4_class(sd$value, "SemImputedData")
  expect_identical(sd$value@method, "lavaan")

  rs <- s4_collect(run_sem(sd$value))
  expect_identical(rs$warnings, "run_sem() is deprecated; use run() on an MDMediationData.")
  res <- rs$value
  expect_s4_class(res, "SemResults")
  expect_length(res@results, m)
  for (i in seq_len(m)) {
    direct <- lavaan::sem(s4_model, data = mice::complete(imp, i))
    expect_equal(
      unname(unlist(res@coef_df[i, -1])),
      unname(lavaan::coef(direct))
    )
  }

  ps <- s4_collect(pool_sem(res))
  expect_true(any(grepl("pool_sem\\(\\) is deprecated", ps$warnings)))
  # m = 2 gives a rank-1 between-imputation covariance: warned, not fatal
  expect_true(any(grepl("cov_between must be a symmetric positive definite", ps$warnings)))
  pooled <- ps$value
  expect_s4_class(pooled, "PooledSEMResults")

  # Known answer: Rubin's rules by hand from the per-imputation table
  est <- res@estimate_df
  ab <- est[est$term == "m ~ x", ]
  q_bar <- mean(ab$estimate)
  b_var <- var(ab$estimate)
  w_var <- mean(ab$std_error^2)
  row <- pooled@tidy_table[pooled@tidy_table$term == "m ~ x", ]
  expect_equal(row$estimate, q_bar)
  expect_equal(row$var_tot, w_var + (1 + 1 / m) * b_var)
  expect_equal(row$std_error, sqrt(w_var + (1 + 1 / m) * b_var))

  co <- as.matrix(as.data.frame(lapply(res@coef_df[, -1], as.numeric)))
  w_mat <- Reduce("+", res@cov_df) / m
  expect_equal(unname(pooled@cov_total), unname(stats::cov(co) * (1 + 1 / m) + w_mat))
})

test_that("pool_sem() refuses a single imputation instead of returning NA SEs", {
  skip_if_not_installed("lavaan")
  imp1 <- mice::mice(s4_data(), m = 1, maxit = 2, seed = 11, printFlag = FALSE)
  res <- suppressWarnings(run_sem(suppressWarnings(set_sem(imp1, s4_model))))
  expect_warning(
    expect_error(pool_sem(res), "pool_sem\\(\\) needs at least 2 imputations; found 1"),
    "deprecated"
  )
})

test_that("show() handles small original data", {
  skip_if_not_installed("lavaan")
  sd <- suppressWarnings(set_sem(s4_mids(m = 2), s4_model))
  out <- capture.output(show(sd))
  expect_match(out[1], "Model Setup:")
  expect_false(any(grepl("^NA", out)))
  sd@original_data <- sd@original_data[1:3, ]
  out3 <- capture.output(show(sd))
  expect_false(any(grepl("^NA", out3)))
})

# ---- OpenMx ----------------------------------------------------------------

test_that("mx_mice() validates its inputs with correct argument names", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  imp <- s4_mids(m = 2)
  expect_error(mx_mice(s4_mx_model(), s4_data()), "'mids' must be a 'mids' object")
  expect_error(mx_mice(s4_model, imp), "^'model' must be an 'MxModel' object")
})

test_that("mx_mice() fits each imputation as mxRun() does, and names failures", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  imp <- s4_mids(m = 2)
  mod <- s4_mx_model()
  fits <- suppressMessages(mx_mice(mod, imp))
  expect_length(fits, 2)
  direct <- suppressMessages(OpenMx::mxRun(
    OpenMx::mxModel(mod, OpenMx::mxData(mice::complete(imp, 2), type = "raw"))
  ))
  expect_equal(coef(fits[[2]]), coef(direct))

  bad <- OpenMx::mxModel("bad",
    type = "RAM", manifestVars = c("x", "zz"),
    OpenMx::mxPath(from = "x", to = "zz")
  )
  expect_error(
    suppressMessages(mx_mice(bad, imp)),
    "OpenMx failed on imputation 1: .*'zz'"
  )

  # '...' reaches mxRun() as documented (dev dropped it silently)
  expect_silent(quiet_fits <- mx_mice(mod, imp, silent = TRUE))
  expect_equal(coef(quiet_fits[[2]]), coef(direct))
  expect_error(
    mx_mice(mod, imp, bogus = 1),
    "OpenMx failed on imputation 1: .*does not accept"
  )
})

test_that("set_sem() -> run_sem() -> pool_sem() works with an MxModel", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  imp <- s4_mids(m = 2)
  sd <- suppressMessages(suppressWarnings(set_sem(imp, s4_mx_model())))
  expect_identical(sd@method, "OpenMx")
  out <- capture.output(show(sd))
  expect_true(any(grepl("Model: an object of class MxRAMModel", out)))

  rs <- suppressMessages(s4_collect(run_sem(sd)))
  expect_identical(rs$warnings, "run_sem() is deprecated; use run() on an MDMediationData.")
  pooled <- suppressWarnings(pool_sem(rs$value))
  tt <- pooled@tidy_table
  a_rows <- rs$value@estimate_df[rs$value@estimate_df$term == "a", ]
  expect_equal(tt$estimate[tt$term == "a"], mean(a_rows$estimate))
})

test_that("tidy.MxModel() validates conf_int and conf_level", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  d <- s4_data()
  fit <- suppressMessages(fit_model(s4_mx_model(), d[stats::complete.cases(d), ]))
  expect_true(is_fit(fit))
  expect_error(tidy(fit, conf_int = NA), "'conf_int' must be a single logical")
  expect_error(
    tidy(fit, conf_int = TRUE, conf_level = 1.5),
    "'conf_level' must be a single numeric value between 0 and 1"
  )
  ci <- tidy(fit, conf_int = TRUE)
  expect_true(all(ci$conf_low < ci$estimate & ci$estimate < ci$conf_high))
})
