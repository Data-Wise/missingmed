test_that("SEM provider validates both branches before pooling in either ARIV mode", {
  model <- "M ~ X; Y ~ M + X"
  fit <- function(model, d) list(fit = NULL, n_obs = nrow(d), improper = FALSE)
  values <- c(4, 9)
  mbco <- function(fit, a, b) list(tests = data.frame(
    constraint = paste(c(a, b), "== 0"), f = c(1, 2),
    diff_ll = values, converged = TRUE))
  local_mocked_bindings(.mm_sem_fit = fit, .mm_sem_mbco = mbco)
  provider <- missingmed:::.mm_sem_provider(model, "X", "M", "Y")
  d <- data.frame(X = 1:3, M = 2:4, Y = 3:5)
  expect_equal(unname(provider(d)), c(0, -2, -4.5, 1, 1), ignore_attr = TRUE)
  for (mode in c("own", "fixed")) {
    for (bad in list(c(-1, 9), c(4, -1), c(Inf, 9), c(4, NA_real_))) {
      values <- bad
      expect_error(missingmed:::.mm_d4_pool(list(d, d), provider, mode),
        "imputation 1.*(negative LR|Non-finite LR)")
    }
  }
  values <- c(-5e-8, 9)
  out <- provider(d)
  expect_match(attr(out, "sem_warnings"), "Roundoff-sized")
  expect_equal(out[["a"]], 0)
  values <- c(-2e-7, 9)
  expect_error(provider(d), "negative LR")
})

test_that("unledgered union routes are refused before any fitting", {
  check <- missingmed:::.mm_sem_complete_syntax
  expect_silent(check("M ~ a*X; Y ~ b*M; a == b"))
  expect_silent(check("M ~ a*X; Y ~ b*M; a == 2*b + 1"))
  for (rhs in c("pi", "T", "F", "unknown", "b + pi")) {
    expect_error(check(paste("M ~ a*X; Y ~ b*M; a ==", rhs)), "completeness")
  }
  for (constraint in c("a*b == 0", "0 == a*b", "a^2 == b", "a > 0")) {
    expect_error(check(paste("M ~ a*X; Y ~ b*M;", constraint)), "completeness")
  }
})

test_that("missing or failed refits cannot produce an accepted provider result", {
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    list(fit = NULL, n_obs = nrow(d), improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) list(tests = data.frame(
    constraint = paste(a, "== 0"), f = 1, diff_ll = 4, converged = TRUE)))
  provider <- missingmed:::.mm_sem_provider("M ~ X; Y ~ M + X", "X", "M", "Y")
  expect_error(provider(data.frame(X = 1)), "incomplete")
})

test_that("stored observed and latent data agree with the lavaan branch oracle", {
  skip_if_not_installed("medfit", "0.10.0")
  cases <- list(
    list(d = setNames(iris[1:4], c("X", "M", "Y", "C")),
      model = "M ~ X + C; Y ~ M + X + C"),
    list(d = lavaan::HolzingerSwineford1939,
      model = "M =~ x4 + x5 + x6; M ~ x1; x9 ~ M + x1")
  )
  null <- cases[[1L]]
  null$d$Y <- residuals(stats::lm(Y ~ M + X + C, data = null$d)) +
    0.2 * null$d$X + 0.3 * null$d$C
  cases <- c(cases, list(null))
  for (case in cases) {
    x <- if ("X" %in% names(case$d)) "X" else "x1"
    y <- if ("Y" %in% names(case$d)) "Y" else "x9"
    sem <- missingmed:::.mm_sem_provider(case$model, x, "M", y)
    lav <- missingmed:::.mm_lav_provider(case$model, x, "M", y)
    got <- sem(case$d)
    ref <- lav(case$d)
    for (branch in c("a", "b")) {
      expect_lt(abs(-2 * got[[branch]] - 2 * (ref[["full"]] - ref[[branch]])), 1e-7)
    }
  }
})

test_that("stack violations and escaping refit failures name their dataset", {
  n <- 0L
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    list(fit = NULL, n_obs = nrow(d), improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) {
    n <<- n + 1L
    list(tests = data.frame(constraint = paste(c(a, b), "== 0"),
      f = c(1, 2), diff_ll = c(4, if (n == 3L) -1 else 9), converged = TRUE))
  })
  p <- missingmed:::.mm_sem_provider("M ~ X; Y ~ M + X", "X", "M", "Y")
  for (mode in c("own", "fixed")) {
    n <- 0L
    expect_error(missingmed:::.mm_d4_pool(list(iris, iris), p, mode),
      "stacked data.*negative LR.*mm_b")
  }
})

test_that("raw LR roundoff policy has a fixed inclusive boundary", {
  lr <- missingmed:::.mm_sem_lr
  expect_warning(expect_equal(lr(-1e-7, "a"), 0), "Roundoff-sized")
  expect_warning(expect_equal(lr(-1e-7 + 1e-12, "b"), 0), "Roundoff-sized")
  expect_error(lr(-1e-7 - 1e-12, "b"), "negative LR.*b")
  expect_equal(lr(0, "a"), 0)
  expect_equal(lr(1e12, "a"), 1e12)
  for (x in c(Inf, -Inf, NaN, NA_real_)) expect_error(lr(x, "a"), "Non-finite")
})

test_that("completeness cannot be inferred from survivor or failure messages", {
  state <- new.env(parent = emptyenv())
  state$tab <- NULL
  state$error <- NULL
  state$drop <- 0L
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    list(fit = NULL, n_obs = nrow(d) - state$drop, improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) {
    if (!is.null(state$error)) stop(state$error)
    list(tests = state$tab)
  })
  p <- missingmed:::.mm_sem_provider("M ~ X; Y ~ M + X", "X", "M", "Y")
  d <- data.frame(X = 1:3)
  good <- data.frame(constraint = c("mm_a == 0", "mm_b == 0"),
    f = c(1, 2), diff_ll = c(1, 9), converged = TRUE)
  for (mode in c("own", "fixed")) {
    for (i in 1:2) {
      state$tab <- good[i, , drop = FALSE]
      expect_error(missingmed:::.mm_d4_pool(list(d, d), p, mode), "imputation 1.*incomplete")
      state$tab <- good
      state$tab$converged[i] <- FALSE
      expect_error(missingmed:::.mm_d4_pool(list(d, d), p, mode), "imputation 1.*incomplete")
    }
    for (msg in c("a = 0 optimizer failure", "b = 0 covariance failure", "all starts failed")) {
      state$error <- msg
      expect_error(missingmed:::.mm_d4_pool(list(d, d), p, mode), paste0("imputation 1.*", msg))
    }
    state$error <- NULL
    state$tab <- good
    state$tab$converged[] <- FALSE
    expect_error(missingmed:::.mm_d4_pool(list(d, d), p, mode), "incomplete")
    state$tab <- good[c(1, 1), ]
    expect_error(missingmed:::.mm_d4_pool(list(d, d), p, mode), "incomplete")
    state$tab <- good
    result <- missingmed:::.mm_d4_pool(list(d, d), p, mode)
    expect_s3_class(result, "S7_object")
    expect_equal(as.numeric(result["d_S"]), 0.5)
    expect_identical(result@stacked_branch, "a")
  }
  state$drop <- 1L
  expect_error(p(d), "dropped observations")
})

test_that("generic products and aliases are rejected before dependency enumeration", {
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  local_mocked_bindings(.mm_sem_fit = function(...) { calls$n <- calls$n + 1L })
  for (con in c("a*b == 0", "0 == a*b", "a*b == 0; a*b == 0",
    "ab := a*b; ab == 0", "a*b*c*d*e*f*g == 0")) {
    expect_error(missingmed:::.mm_sem_provider(paste("M ~ a*X; Y ~ b*M;", con),
      "X", "M", "Y"), "completeness")
  }
  expect_equal(calls$n, 0L)
})

test_that("pooled warnings are emitted once with all dataset names", {
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    warning("first start was not accepted", call. = FALSE)
    list(fit = NULL, n_obs = nrow(d), improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) {
    warning("mixture of chi-squares", call. = FALSE)
    list(tests = data.frame(constraint = paste(c(a, b), "== 0"),
      f = c(1, 2), diff_ll = c(4, 9), converged = TRUE))
  })
  p <- missingmed:::.mm_sem_provider("M ~ X; Y ~ M + X", "X", "M", "Y")
  messages <- character()
  withCallingHandlers(missingmed:::.mm_d4_pool(list(iris, iris), p), warning = function(w) {
    messages <<- c(messages, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_length(messages, 1L)
  for (s in c("imputation 1", "imputation 2", "stacked data", "first start", "mixture")) {
    expect_match(messages, s)
  }
})

test_that("unimplemented options and full-fit errors never silently fall through", {
  expect_error(missingmed:::.mm_sem_provider("M ~ X; Y ~ M", "X", "M", "Y",
    list(auto.cov.y = FALSE)), "fit_args")
  local_mocked_bindings(.mm_sem_fit = function(...) stop("full optimizer failed"))
  p <- missingmed:::.mm_sem_provider("M ~ X; Y ~ M", "X", "M", "Y")
  expect_error(missingmed:::.mm_d4_pool(list(iris, iris), p),
    "imputation 1.*full model.*full optimizer failed")
})

test_that("real affine equality nulls retain one dimension and match the oracle", {
  skip_if_not_installed("medfit", "0.10.0")
  d <- setNames(iris[1:4], c("X", "M", "Y", "C"))
  for (con in c("a == b", "a == 2*b + 1")) {
    model <- paste("M ~ a*X + C; Y ~ b*M + X + C;", con)
    got <- missingmed:::.mm_sem_provider(model, "X", "M", "Y")(d)
    full <- lavaan::sem(model, data = d, fixed.x = FALSE)
    for (branch in c("a", "b")) {
      null <- lavaan::sem(paste(model, paste0(branch, " == 0"), sep = "\n"),
        data = d, fixed.x = FALSE)
      expect_equal(lavaan::fitMeasures(null, "df") - lavaan::fitMeasures(full, "df"),
        c(df = 1), ignore_attr = TRUE)
      expected <- 2 * (lavaan::fitMeasures(full, "logl") - lavaan::fitMeasures(null, "logl"))
      expect_lt(abs(-2 * got[[branch]] - expected), 1e-7)
    }
  }
  for (con in c("a == 0", "a == 1", "a == b; b == 0")) {
    expect_error(missingmed:::.mm_sem_provider(
      paste("M ~ a*X; Y ~ b*M;", con), "X", "M", "Y"), "no additional dimension")
  }
})

test_that("diagnostic notices survive a later refit failure", {
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    warning("starts disagree", call. = FALSE)
    list(fit = NULL, n_obs = nrow(d), improper = FALSE)
  }, .mm_sem_mbco = function(...) stop("b = 0 covariance failure"))
  p <- missingmed:::.mm_sem_provider("M ~ X; Y ~ M", "X", "M", "Y")
  expect_error(p(iris), "b = 0 covariance failure.*Collected warnings: starts disagree")
})

test_that("shared regression and intercept labels remain one-dimensional", {
  skip_if_not_installed("medfit", "0.10.0")
  d <- setNames(iris[1:4], c("X", "M", "Y", "C"))
  for (model in c("M ~ a*X + C; Y ~ b*M + a*X + C",
    "M ~ a*X + C; Y ~ b*M + X + C; Y ~ a*1")) {
    got <- missingmed:::.mm_sem_provider(model, "X", "M", "Y")(d)
    full <- lavaan::sem(model, data = d, fixed.x = FALSE)
    for (branch in c("a", "b")) {
      null <- lavaan::sem(paste(model, paste(branch, "== 0"), sep = ";"),
        data = d, fixed.x = FALSE)
      expect_equal(unname(lavaan::fitMeasures(null, "df") - lavaan::fitMeasures(full, "df")), 1)
      lr <- 2 * (lavaan::fitMeasures(full, "logl") - lavaan::fitMeasures(null, "logl"))
      expect_lt(abs(-2 * got[[branch]] - lr), 1e-7)
    }
  }
})

test_that("affine closure refuses nonpositive variance nulls but preserves positive ones", {
  base <- "M ~ a*X + w*C; X ~~ v*X; Y ~ b*M + X"
  for (constraint in c("a == v", "v == a", "a == 2*v", "a == 2*v + 1",
    "a == w; w == v", "b == v")) {
    expect_error(missingmed:::.mm_sem_provider(paste(base, constraint, sep = ";"),
      "X", "M", "Y"), "null.*(nonpositive|infeasible joint variance)")
  }
  expect_silent(missingmed:::.mm_sem_provider(paste(base, "v == a + 1", sep = ";"),
    "X", "M", "Y"))
  expect_silent(missingmed:::.mm_sem_provider(paste(base, "v == a + w", sep = ";"),
    "X", "M", "Y"))
})

test_that("joint variance feasibility and redundant equality consistency fail closed", {
  base <- "M ~ a*X + w*C; Y ~ b*M + X; X ~~ v1*X; M ~~ v2*M"
  for (con in c("a == v1 + v2", "a == 2*v1 + v2", "a == w; w == v1 + v2")) {
    expect_error(missingmed:::.mm_sem_provider(paste(base, con, sep = ";"),
      "X", "M", "Y"), "a = 0 null.*infeasible joint variance")
  }
  expect_error(missingmed:::.mm_sem_provider(paste(base,
    "v1 == v2; v1 == v2 + 1", sep = ";"), "X", "M", "Y"), "Inconsistent equalities")
  for (con in c("a == v1 - v2", "a == v1 + v2 - 1", "v1 == v2; 2*v1 == 2*v2")) {
    expect_silent(missingmed:::.mm_sem_provider(paste(base, con, sep = ";"), "X", "M", "Y"))
  }
})

test_that("affine feasibility controls cover scaling, contradictions and work limits", {
  feasible <- missingmed:::.mm_sem_feasible
  expect_true(feasible(matrix(c(1, -1), 1), 0, 1:2))
  expect_false(feasible(matrix(c(1, 1), 1), 0, 1:2))
  expect_true(feasible(matrix(c(1, 1), 1), 1, 1:2))
  expect_false(feasible(matrix(c(1, 1), 2), c(0, 1), integer()))
  expect_false(feasible(matrix(c(1e4, 1e4), 1), 0, 1:2))
  expect_error(feasible(matrix(1, 65, 1), rep(1, 65), integer()), "limit exceeded")
  expect_error(feasible(matrix(c(1e-14, 1), 1), 0, 1:2), "ill-scaled")
})
