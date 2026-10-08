# Edge cases and defensive checks for set_md_mediation() -> run() -> pool() ->
# infer(), the IPW path, and the engine checks and engine-call wrapper.

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

edge_data <- function(n = 120, seed = 11) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.45 * X + 0.25 * C + rnorm(n)
  Y <- 0.25 * X + 0.35 * M + 0.2 * C + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C = C)
}
edge_miss <- function(d, k = 20, seed = 12) {
  set.seed(seed)
  d$M[sample(nrow(d), k)] <- NA
  d$Y[sample(nrow(d), k)] <- NA
  d
}
edge_imp <- function(d, m = 2, ...) {
  mice::mice(d, m = m, printFlag = FALSE, seed = 1, ...)
}
edge_md <- function(imp, fy = Y ~ X + M + C, fm = M ~ X + C, ...) {
  set_md_mediation(imp, fy, fm, treatment = "X", mediator = "M", ...)
}

d_full <- edge_data()
d_miss <- edge_miss(d_full)
imp2 <- edge_imp(d_miss)
fit2 <- run(edge_md(imp2))
res2 <- pool(fit2)
fit_xm <- run(edge_md(imp2, fy = Y ~ X * M + C))

# ---- No missing values / m = 1 ---------------------------------------------

test_that("no missing values: B = 0 gives finite Rubin quantities, and the single fit", {
  fit <- run(edge_md(edge_imp(d_full, m = 3)))
  tt <- pool(fit)@tidy_table
  expect_true(all(tt$var_b == 0))
  expect_true(all(tt$riv == 0))
  expect_true(all(is.finite(as.matrix(tt[, -1]))))
  expect_true(all(tt$df > 0 & tt$fmi >= 0 & tt$fmi < 1))
  # Every completed dataset is the data, so the pooled fit is the single fit.
  one <- medfit::fit_mediation(Y ~ X + M + C, M ~ X + C, data = d_full,
    treatment = "X", mediator = "M")
  expect_equal(tt$estimate, unname(one@estimates[tt$term]))
  expect_equal(tt$std_error, unname(sqrt(diag(one@vcov))[tt$term]))
  ci <- infer(fit, n.mc = 2000)$CI
  expect_true(all(is.finite(ci)) && ci[1] < ci[2])
  r <- infer(fit, type = "mbco")
  expect_equal(r[["r4"]], 0)
  expect_true(is.finite(r[["p"]]))
})

test_that("no missing values with a binomial outcome: df = Inf rows stay finite", {
  d <- d_full
  d$Y <- as.integer(d$Y > 0)
  tt <- pool(run(edge_md(edge_imp(d), family_y = stats::binomial())))@tidy_table
  y_rows <- startsWith(tt$term, "y_") | tt$term %in% c("b", "c_prime")
  expect_true(all(is.infinite(tt$df[y_rows])))
  expect_true(all(tt$fmi[y_rows] == 0))
  expect_true(all(is.finite(tt$p_value)))
})

test_that("m = 1: Rubin reduces to the single-fit Wald test; MBCO refuses", {
  fit <- run(edge_md(edge_imp(d_miss, m = 1)))
  tt <- pool(fit)@tidy_table
  expect_true(all(tt$riv == 0 & tt$fmi == 0))
  expect_equal(tt$df[tt$term == "a"], nrow(d_miss) - 3)
  expect_equal(tt$df[tt$term == "b"], nrow(d_miss) - 4)
  expect_true(all(is.finite(infer(fit, n.mc = 1000)$CI)))
  expect_error(infer(fit, type = "mbco"), "at least 2 imputations")
})

# ---- Names ------------------------------------------------------------------

test_that("non-syntactic treatment or mediator names are refused at set time", {
  dn <- d_miss
  names(dn)[names(dn) == "M"] <- "my M"
  impn <- edge_imp(dn)
  expect_error(
    set_md_mediation(impn, Y ~ X + `my M` + C, `my M` ~ X + C,
      treatment = "X", mediator = "my M"),
    "`mediator` 'my M' is not a syntactic R name", fixed = TRUE
  )
  dx <- d_miss
  names(dx)[names(dx) == "X"] <- "trt x"
  expect_error(
    set_md_mediation(edge_imp(dx), Y ~ `trt x` + M + C, M ~ `trt x` + C,
      treatment = "trt x", mediator = "M"),
    "`treatment` 'trt x' is not a syntactic R name", fixed = TRUE
  )
  # IPW goes through the same check.
  expect_error(
    set_md_mediation(dn, Y ~ X + `my M` + C, `my M` ~ X + C,
      treatment = "X", mediator = "my M", method = "ipw"),
    "not a syntactic R name"
  )
})

test_that("treatment equal to mediator, or an empty role, is refused", {
  expect_error(
    set_md_mediation(imp2, Y ~ X + M + C, M ~ M + X + C,
      treatment = "M", mediator = "M"),
    "`treatment` and `mediator` are both 'M'", fixed = TRUE
  )
  expect_error(
    set_md_mediation(imp2, Y ~ X + M + C, M ~ X + C,
      treatment = "", mediator = "M"),
    "`treatment` must be a single variable name", fixed = TRUE
  )
})

test_that(".check_roles() accepts `.` on a right-hand side", {
  # Without data (mbco_d4() has none at that point) the predictor check is
  # skipped for a dotted formula; with data, `.` is expanded first.
  expect_true(.check_roles(Y ~ ., M ~ X + C, "X", "M"))
  expect_true(.check_roles(Y ~ ., M ~ ., "X", "M"))
  expect_true(.check_roles(Y ~ ., M ~ X + C, "X", "M", data = d_full))
  expect_error(.check_roles(Y ~ ., M ~ X + C, "X", "M", data = d_full[-2]),
    "`mediator` 'M' is not a predictor in `formula_y`", fixed = TRUE)
})

test_that("a non-syntactic covariate name runs end to end", {
  dc <- d_miss
  names(dc)[names(dc) == "C"] <- "my C"
  fit <- run(set_md_mediation(edge_imp(dc), Y ~ X + M + `my C`, M ~ X + `my C`,
    treatment = "X", mediator = "M"))
  res <- pool(fit)
  expect_equal(res@tidy_table$estimate, res2@tidy_table$estimate)
  expect_true(all(is.finite(infer(res, n.mc = 1000)$CI)))
})

# ---- Engines ----------------------------------------------------------------

test_that("unknown engines are refused at set time, naming the supported ones", {
  expect_error(edge_md(imp2, engine = "lm"),
    "`engine` \"lm\" is not supported. Supported: \"glm\"", fixed = TRUE)
  # "lavaan" is supported, but takes `model`, not formulas (see test-lavaan-spec.R).
  expect_error(edge_md(imp2, engine = "lavaan"), "cannot be used with engine")
  expect_error(edge_md(imp2, engine = "GLM"), "not supported")
  for (bad in list(NA_character_, c("glm", "regmedint"), 1, character(0))) {
    expect_error(edge_md(imp2, engine = bad), "`engine` must be a single string")
  }
})

test_that("regmedint is refused for IPW on any medfit, with the same message", {
  expect_error(edge_md(d_miss, method = "ipw", engine = "regmedint"),
    "takes no case weights")
  local_mocked_bindings(.medfit_version = function() numeric_version("0.3.2"))
  expect_error(edge_md(d_miss, method = "ipw", engine = "regmedint"),
    "takes no case weights")
})

test_that("regmedint needs medfit >= 0.4.0", {
  local_mocked_bindings(.medfit_version = function() numeric_version("0.3.2"))
  expect_error(edge_md(imp2, engine = "regmedint"),
    "needs medfit >= 0.4.0 (installed: 0.3.2)", fixed = TRUE)
  expect_identical(.md_engines("mi"), c("glm", "lavaan"))
})

test_that("regmedint runs end to end and matches glm on a Gaussian model", {
  skip_if(utils::packageVersion("medfit") < "0.4.0", "medfit < 0.4.0")
  skip_if_not_installed("regmedint")
  fit <- run(edge_md(imp2, engine = "regmedint"))
  res <- pool(fit)
  expect_equal(res@tidy_table, res2@tidy_table)
  set.seed(5)
  a <- infer(res, n.mc = 1000)
  set.seed(5)
  b <- infer(res2, n.mc = 1000)
  expect_equal(a$CI, b$CI)
})

test_that("run() checks the engine of an object not built by set_md_mediation()", {
  md <- edge_md(imp2)
  md@engine <- "lm"
  expect_error(run(md), "`engine` \"lm\" is not supported", fixed = TRUE)
  md_ipw <- edge_md(d_miss, method = "ipw")
  md_ipw@engine <- "regmedint"
  expect_error(run(md_ipw), "takes no case weights")
})

# ---- Engine-call wrapper ----------------------------------------------------

test_that("run() leaves clean fits untouched and raises no warning", {
  expect_no_warning(fit <- run(edge_md(imp2)))
  direct <- lapply(mice::complete(imp2, action = "all"), function(d) {
    medfit::fit_mediation(Y ~ X + M + C, M ~ X + C, data = d,
      treatment = "X", mediator = "M")@estimates
  })
  expect_equal(lapply(fit@per_imputation, function(x) x@estimates), direct)
  expect_identical(names(fit@per_imputation), names(direct))
})

test_that("an engine error names the engine and the imputation", {
  real <- .md_engine_call
  calls <- 0
  local_mocked_bindings(.md_engine_call = function(object, data, ...) {
    calls <<- calls + 1
    if (calls == 2) stop("planted failure")
    real(object, data, ...)
  })
  expect_error(run(edge_md(edge_imp(d_miss, m = 3))),
    "engine \"glm\" failed on imputation 2 of 3: planted failure", fixed = TRUE)
})

test_that("a real engine error is labelled too", {
  # A binomial mediator model on a continuous mediator fails in glm().
  expect_error(run(edge_md(imp2, family_m = stats::binomial())),
    "engine \"glm\" failed on imputation 1 of 2: .*y values must be")
})

test_that("engine warnings are raised once, naming the imputations", {
  real <- .md_engine_call
  calls <- 0
  local_mocked_bindings(.md_engine_call = function(object, data, ...) {
    calls <<- calls + 1
    if (calls %in% c(1, 3)) warning("planted warning")
    if (calls == 1) message("planted message")
    real(object, data, ...)
  })
  expect_message(
    w <- testthat::capture_warnings(run(edge_md(edge_imp(d_miss, m = 3)))),
    "planted message"
  )
  expect_length(w, 1)
  expect_identical(w,
    "engine \"glm\" warned on imputations 1, 3 of 3: planted warning")
})

test_that("IPW fits are wrapped the same way", {
  local_mocked_bindings(.md_engine_call = function(object, data, ...) {
    stop("planted failure")
  })
  expect_error(run(edge_md(d_miss, method = "ipw")),
    "engine \"glm\" failed on the IPW fit: planted failure", fixed = TRUE)
})

test_that("IPW engine warnings name the IPW fit", {
  real <- .md_engine_call
  local_mocked_bindings(.md_engine_call = function(object, data, ...) {
    warning("planted warning")
    real(object, data, ...)
  })
  expect_warning(run(edge_md(d_miss, method = "ipw")),
    "engine \"glm\" warned on the IPW fit: planted warning", fixed = TRUE)
})

test_that("warnings before an engine error are still raised", {
  real <- .md_engine_call
  calls <- 0
  local_mocked_bindings(.md_engine_call = function(object, data, ...) {
    calls <<- calls + 1
    if (calls == 1) warning("early warning")
    if (calls == 2) {
      warning("same-fit warning")
      stop("planted failure")
    }
    real(object, data, ...)
  })
  w <- testthat::capture_warnings(
    expect_error(run(edge_md(edge_imp(d_miss, m = 3))),
      "failed on imputation 2 of 3: planted failure (after warning: same-fit warning)",
      fixed = TRUE
    )
  )
  expect_identical(w, "engine \"glm\" warned on imputation 1 of 3: early warning")
})

test_that("a rethrown engine error keeps the original condition class", {
  local_mocked_bindings(.md_engine_call = function(object, data, ...) {
    stop(errorCondition("planted", class = "planted_error"))
  })
  expect_error(run(edge_md(imp2)), class = "planted_error")
  e <- tryCatch(run(edge_md(imp2)), error = identity)
  expect_s3_class(e$engine_error, "planted_error")
})

test_that("a model variable mice left unimputed is warned about", {
  dc <- d_miss
  set.seed(13)
  dc$C[sample(nrow(dc), 15)] <- NA
  imp <- edge_imp(dc, method = c("", "pmm", "pmm", ""))
  # mice cannot impute M or Y on rows where their predictor C is missing, so
  # those stay incomplete too.
  expect_warning(fit <- run(edge_md(imp)),
    "Model variables 'Y', 'M', 'C' still have missing values after imputation",
    fixed = TRUE)
  expect_warning(run(edge_md(edge_imp(d_miss))), NA)
  expect_s7_class(fit, MDMediationFit)
})

test_that("separation warns once and is not hidden behind a huge SE", {
  set.seed(3)
  ds <- data.frame(X = rbinom(120, 1, 0.5), C = rnorm(120))
  ds$M <- as.integer(ds$C > 0) # C separates M perfectly
  ds$Y <- 0.3 * ds$M + 0.2 * ds$X + 0.2 * ds$C + rnorm(120)
  ds$Y[sample(120, 20)] <- NA
  w <- testthat::capture_warnings(
    fit <- run(edge_md(edge_imp(ds), family_m = stats::binomial()))
  )
  expect_length(w, 1)
  expect_match(w, "imputations 1, 2 of 2: .*did not converge")
  # The pooled SE of a is huge; the warning above is the user's signal.
  tt <- pool(fit)@tidy_table
  expect_gt(tt$std_error[tt$term == "a"], 100)
})

# ---- IPW ----------------------------------------------------------------------

test_that("IPW with no complete case stops before fitting", {
  dz <- d_full
  dz$M[1:60] <- NA
  dz$Y[61:120] <- NA
  md <- edge_md(dz, method = "ipw")
  expect_error(run(md), "No complete cases")
  expect_no_warning(try(run(md), silent = TRUE))
})

test_that("IPW with every row complete gives weights of exactly 1, no warning", {
  expect_no_warning(fit <- run(edge_md(d_full, method = "ipw")))
  expect_identical(fit@weights, rep(1, nrow(d_full)))
  ref <- medfit::fit_mediation(Y ~ X + M + C, M ~ X + C, data = d_full,
    treatment = "X", mediator = "M")
  expect_equal(fit@per_imputation[[1]]@estimates, ref@estimates)
})

test_that("weight_trim and weight_stabilize are validated at set time", {
  for (bad in list(0, 1.5, NA_real_, c(0.9, 0.95), "0.9")) {
    expect_error(edge_md(d_miss, method = "ipw", weight_trim = bad),
      "`weight_trim` must be a single number in (0, 1]", fixed = TRUE)
  }
  for (bad in list(NA, "yes", c(TRUE, FALSE))) {
    expect_error(edge_md(d_miss, method = "ipw", weight_stabilize = bad),
      "`weight_stabilize` must be TRUE or FALSE", fixed = TRUE)
  }
  expect_error(edge_md(d_miss, method = "ipw", se_type = "HC3"),
    "should be one of")
})

test_that("a tiny weight_trim caps every weight: an unweighted fit", {
  fit <- run(edge_md(d_miss, method = "ipw", weight_trim = 1e-6))
  w <- fit@weights[!is.na(fit@weights)]
  expect_equal(max(w) - min(w), 0, tolerance = 1e-6)
})

test_that("weight_formula must be a formula or a named list of formulas", {
  expect_error(edge_md(d_miss, method = "ipw", weight_formula = "X + C"),
    "`weight_formula` must be NULL, a formula")
  expect_error(edge_md(d_miss, method = "ipw", weight_formula = list(~ X + C)),
    "`weight_formula` must be NULL, a formula")
  expect_error(edge_md(d_miss, method = "ipw", weight_formula = list()),
    "`weight_formula` must be NULL, a formula")
  expect_error(
    edge_md(d_miss, method = "ipw", weight_formula = list(M = "X")),
    "`weight_formula` must be NULL, a formula"
  )
})

test_that("weight_formula variables must exist", {
  expect_error(edge_md(d_miss, method = "ipw", weight_formula = ~ X + Z),
    "`weight_formula` uses 'Z', not found in `data`", fixed = TRUE)
  expect_error(
    edge_md(d_miss, method = "ipw", weight_formula = list(M = ~ X + Z, Y = ~ X)),
    "'Z', not found"
  )
  # Naming a variable that is not a column is caught by run(), as before.
  md <- edge_md(d_miss, method = "ipw", weight_formula = list(Q = ~ X))
  expect_error(run(md), "names variables not in the data: 'Q'")
  expect_error(edge_md(d_miss, method = "ipw", weight_formula = ~ .),
    "cannot use `.`", fixed = TRUE)
  # Method "mi" ignores weight_formula, so it is not checked there.
  expect_s7_class(edge_md(imp2, weight_formula = ~ X + Z), MDMediationData)
  # A constant from the formula's environment is a valid predictor term, at
  # set time and in run().
  k <- 2
  md <- edge_md(d_miss, method = "ipw", weight_formula = ~ X + I(C * k))
  expect_s7_class(md, MDMediationData)
  expect_s7_class(run(md), MDMediationFit)
})

test_that("weight_formula names resolve in the user's environment", {
  # `n` is also a local of the weight code (the row count); the user's wins.
  n <- 0.5
  lit <- run(edge_md(d_miss, method = "ipw", weight_formula = ~ X + I(C > 0.5)))
  sym <- run(edge_md(d_miss, method = "ipw", weight_formula = ~ X + I(C > n)))
  expect_equal(sym@weights, lit@weights)
  sym_v <- run(edge_md(d_miss, method = "ipw",
    weight_formula = list(M = ~ X + I(C > n), Y = ~ X)))
  lit_v <- run(edge_md(d_miss, method = "ipw",
    weight_formula = list(M = ~ X + I(C > 0.5), Y = ~ X)))
  expect_equal(sym_v@weights, lit_v@weights)
})

test_that("a `.` in a model formula is expanded for fitting, so run() works", {
  md <- edge_md(imp2, fy = Y ~ .)
  expect_identical(md@formula_y, Y ~ .) # stored as given
  fit <- run(md)
  expect_equal(pool(fit)@tidy_table, res2@tidy_table)
  expect_equal(infer(fit, type = "mbco"), infer(fit2, type = "mbco"))
  ipw <- run(edge_md(d_miss, fy = Y ~ ., method = "ipw"))
  ref <- run(edge_md(d_miss, method = "ipw"))
  expect_equal(ipw@per_imputation[[1]]@estimates, ref@per_imputation[[1]]@estimates)
  expect_identical(ipw@weights, ref@weights)
})

test_that("a two-sided weight_formula is accepted; its response is ignored", {
  f1 <- run(edge_md(d_miss, method = "ipw", weight_formula = R ~ X + C))
  f2 <- run(edge_md(d_miss, method = "ipw", weight_formula = ~ X + C))
  expect_identical(f1@weights, f2@weights)
})

test_that("se_type = 'model' and 'sandwich' give the same estimates, other SEs", {
  fm <- suppressMessages(run(edge_md(d_miss, method = "ipw", se_type = "model")))
  fs <- run(edge_md(d_miss, method = "ipw", se_type = "sandwich"))
  tm <- pool(fm)@tidy_table
  ts <- pool(fs)@tidy_table
  expect_equal(tm$estimate, ts$estimate)
  expect_false(isTRUE(all.equal(tm$std_error, ts$std_error)))
})

test_that("conf_int must be TRUE or FALSE", {
  expect_error(edge_md(imp2, conf_int = NA), "'conf_int' must be a single logical")
})

# ---- pool() -----------------------------------------------------------------

test_that("pool() reorders an imputation whose coefficients come in another order", {
  pi <- fit2@per_imputation
  o <- rev(seq_along(pi[[2]]@estimates))
  S7::props(pi[[2]]) <- list(
    estimates = pi[[2]]@estimates[o], vcov = pi[[2]]@vcov[o, o]
  )
  fb <- fit2
  fb@per_imputation <- pi
  rb <- pool(fb)
  expect_equal(rb@tidy_table, res2@tidy_table)
  expect_equal(rb@cov_total, res2@cov_total)
})

test_that("pool() reorders by name even when vcov has its own order", {
  pi <- fit2@per_imputation
  e <- pi[[2]]@estimates
  o <- rev(seq_along(e))
  s <- c(2, 1, seq_along(e)[-(1:2)])
  S7::props(pi[[2]]) <- list(estimates = e[o], vcov = pi[[2]]@vcov[s, s])
  fb <- fit2
  fb@per_imputation <- pi
  expect_equal(pool(fb)@tidy_table, res2@tidy_table)
})

test_that("pool() refuses imputations with different coefficients", {
  pi <- fit2@per_imputation
  e2 <- pi[[2]]@estimates
  names(e2)[names(e2) == "m_C"] <- "m_Z"
  S7::props(pi[[2]]) <- list(estimates = e2)
  fb <- fit2
  fb@per_imputation <- pi
  expect_error(pool(fb),
    "imputation 2 estimates different coefficients from imputation 1 (only in imputation 1: m_C; only in imputation 2: m_Z)",
    fixed = TRUE
  )
  pi <- fit2@per_imputation
  k <- seq_len(length(pi[[2]]@estimates) - 1)
  S7::props(pi[[2]]) <- list(
    estimates = pi[[2]]@estimates[k], vcov = pi[[2]]@vcov[k, k]
  )
  fb@per_imputation <- pi
  expect_error(pool(fb), "estimates different coefficients")
})

test_that("pool() on NULL or a data.frame says what it takes", {
  expect_error(pool(NULL), "takes the MDMediationFit returned by `run()`",
    fixed = TRUE)
  expect_error(pool(d_full), "not a data.frame")
})

test_that("run() and infer() refuse the wrong object type", {
  expect_error(run(d_full), "Can't find method")
  expect_error(run(fit2), "Can't find method")
  expect_error(infer(d_full), "Can't find method")
  expect_error(infer(edge_md(imp2)), "Can't find method")
})

# ---- theta3 = 0 in an X:M fit -------------------------------------------------

test_that("an exactly-zero interaction recovers m_ref from the covariate means", {
  fit <- fit_xm@per_imputation[[1]]
  skip_if(is.null(attr(fit@data, "medfit_covariate_means")),
    "medfit does not store covariate means (< 0.4.0)")
  m_ref <- .interaction_m_ref(fit)
  S7::prop(fit, "interaction", check = FALSE) <- 0
  expect_equal(.interaction_m_ref(fit), m_ref)
})

test_that("an exactly-zero interaction without covariate means is a clear error", {
  fit <- fit_xm@per_imputation[[1]]
  S7::prop(fit, "interaction", check = FALSE) <- 0
  d0 <- fit@data
  attr(d0, "medfit_covariate_means") <- NULL
  S7::prop(fit, "data", check = FALSE) <- d0
  expect_error(.interaction_m_ref(fit), "Update medfit")
})

# ---- infer() arguments ------------------------------------------------------

test_that("`level` must lie strictly inside (0, 1)", {
  for (bad in list(0, 1, 1.5, -0.1, NA_real_, c(0.9, 0.95), "0.9")) {
    expect_error(infer(fit2, level = bad, n.mc = 100),
      "`level` must be a single number in (0, 1)", fixed = TRUE)
  }
  expect_error(infer(res2, level = 0, n.mc = 100), "`level` must be")
  expect_error(infer(fit_xm, treatment_level = 1, level = 2, n.mc = 100),
    "`level` must be")
})

test_that("`n.mc` must be a whole number of at least 2", {
  for (bad in list(0, 1, -5, 10.5, NA_real_, Inf, c(100, 200))) {
    expect_error(infer(fit2, n.mc = bad),
      "`n.mc` must be a single whole number of at least 2", fixed = TRUE)
  }
  expect_error(infer(fit_xm, treatment_level = 1, n.mc = 1), "`n.mc` must be")
  # Tiny but valid: runs, with a large Monte-Carlo error.
  expect_true(all(is.finite(infer(fit2, n.mc = 10)$CI)))
})

test_that("unknown `type` and `ariv` are clear errors", {
  expect_error(infer(fit2, type = "boot"), "should be one of")
  expect_error(infer(res2, type = "boot"), "should be one of")
  expect_error(infer(fit2, type = "mbco", ariv = "x"), "should be one of")
})

test_that("unused arguments are errors, not silently dropped", {
  expect_error(infer(fit2, conf.level = 0.9, n.mc = 100),
    "Unused argument in `infer()`: `conf.level`", fixed = TRUE)
  expect_error(infer(fit2, nmc = 10, levl = 0.9),
    "Unused arguments in `infer()`: `nmc`, `levl`", fixed = TRUE)
  expect_error(infer(res2, conf.level = 0.9), "Unused argument")
  expect_error(infer(res2, ariv = "own"), "`ariv`")
  # The value of a stray argument is never evaluated.
  expect_error(infer(fit2, conf.level = no_such_object), "`conf.level`")
  expect_error(infer(fit2, "mc", 0.9, 100, "fixed", NULL, 7), "<unnamed>")
  # The MBCO refusal on a pooled result still comes first.
  expect_error(infer(res2, type = "mbco", ariv = "own"), "does not commute")
})

test_that("`treatment_level` checks are pinned", {
  for (bad in list(NA_real_, Inf, c(0, 1), "1")) {
    expect_error(infer(fit_xm, treatment_level = bad, n.mc = 100),
      "`treatment_level` must be a single finite number", fixed = TRUE)
  }
  expect_error(infer(fit2, treatment_level = 1, n.mc = 100),
    "applies only to models with a treatment-by-")
  expect_error(infer(fit_xm, n.mc = 100), "Set `treatment_level`")
})

test_that("MBCO needs the originating MDMediationData", {
  fb <- fit2
  fb@source <- NULL
  expect_error(infer(fb, type = "mbco"), "MBCO needs the originating")
})

test_that("an aliased path coefficient is a clear error; an aliased covariate is not", {
  da <- d_miss
  da$K <- da$M # K duplicates M, so y_M is aliased in every imputation
  # mice warns that it logged the collinearity; that is not under test.
  impa <- suppressWarnings(edge_imp(da, method = c("", "pmm", "pmm", "", "")))
  # K is left unimputed (method ""), so it is still a copy of M; run() says so.
  expect_warning(fit <- run(edge_md(impa, fy = Y ~ X + K + M + C)),
    "'K' still has missing values")
  tt <- pool(fit)@tidy_table
  expect_true(is.na(tt$estimate[tt$term == "b"]))
  expect_error(infer(fit, n.mc = 100), "The pooled `b` is NA", fixed = TRUE)

  dk <- d_miss
  dk$K <- 1 # a constant covariate: y_K is NA, a and b are fine
  fit_k <- run(edge_md(suppressWarnings(edge_imp(dk)), fy = Y ~ X + M + C + K))
  expect_true(all(is.finite(infer(fit_k, n.mc = 1000)$CI)))
})

test_that("infer() warns about arguments the chosen type does not use", {
  set.seed(61)
  n <- 120
  d <- data.frame(X = rnorm(n), C = rnorm(n))
  d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
  d$M[sample(n, 20)] <- NA
  imp <- mice::mice(d, m = 2, maxit = 2, method = "norm", printFlag = FALSE, seed = 4)
  fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  ))
  # v0.5.0 dropped these silently.
  expect_warning(r <- infer(fit, type = "mbco", level = 0.9, n.mc = 100),
    "Ignored for type = \"mbco\": `level`, `n.mc`.", fixed = TRUE
  )
  expect_equal(S7::S7_data(r), S7::S7_data(infer(fit, type = "mbco")))
  expect_warning(infer(fit, type = "mbco", treatment_level = 1),
    "`treatment_level`", fixed = TRUE
  )
  expect_warning(infer(fit, type = "mc", ariv = "own", n.mc = 1000),
    "Ignored for type = \"mc\": `ariv`.", fixed = TRUE
  )
  # Defaults and the arguments a type does use stay silent.
  expect_silent(infer(fit, type = "mbco", ariv = "own"))
  expect_silent(infer(fit, type = "mc", level = 0.9, n.mc = 1000))
})
