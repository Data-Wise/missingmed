# Public SEM migration: stored complete observations, no stochastic imputation.
skip_if_not_installed("medfit", "0.10.0")
sem_public_data <- setNames(iris[1:4], c("X", "M", "Y", "C"))
sem_public_model <- "M ~ X + C; Y ~ M + X + C"
sem_public_imps <- list(sem_public_data, sem_public_data)
sem_public_mids <- function() {
  long <- do.call(rbind, lapply(0:2, function(i) {
    data.frame(.imp = i, .id = seq_len(nrow(sem_public_data)), sem_public_data)
  }))
  # as.mids expects an initialized seed even with no missing entries. No
  # imputed values are generated; restore the caller's RNG state afterward.
  withr::with_seed(1, mice::as.mids(long))
}
sem_public_md <- function(args = list()) set_md_mediation(sem_public_mids(),
  model = sem_public_model, treatment = "X", mediator = "M", outcome = "Y",
  engine = "lavaan", fit_args = args)
sem_public_direct <- function(imps = sem_public_imps, args = list(), ...) {
  mbco_d4(imps, model = sem_public_model, treatment = "X", mediator = "M",
    outcome = "Y", fit_args = args, ...)
}

test_that("both public paths use medfit and agree under either ARIV", {
  fit <- run(sem_public_md())
  original <- missingmed:::.mm_sem_provider
  calls <- 0L
  local_mocked_bindings(.mm_sem_provider = function(...) {
    calls <<- calls + 1L
    original(...)
  })
  for (mode in c("fixed", "own")) {
    direct <- sem_public_direct(ariv = mode)
    via <- infer(fit, type = "mbco", ariv = mode)
    glm <- mbco_d4(sem_public_imps, Y ~ M + X + C, M ~ X + C,
      treatment = "X", mediator = "M", ariv = mode)
    expect_equal(via, direct, tolerance = 1e-7)
    expect_equal(as.vector(direct), as.vector(glm), tolerance = 1e-7)
    expect_identical(direct@stacked_branch, glm@stacked_branch)
    expect_equal(direct@k, 1)
    expect_true(is.na(direct@scaling))
  }
  expect_equal(calls, 4L)
})

test_that("NULL fit_args retains existing public rejection", {
  expect_error(sem_public_direct(args = NULL), "fit_args.*must be a list")
  expect_error(sem_public_md(NULL), "fit_args.*must be a list")
  expect_equal(sem_public_direct(args = list()), sem_public_direct())
})

test_that("public SEM restrictions precede refitting, with no MLR escape hatch", {
  withr::local_options(missingmed.internal_mlr = TRUE)
  fit <- run(sem_public_md(list(estimator = "MLR")))
  local_mocked_bindings(.mm_sem_fit = function(...) stop("unexpected fit"))
  expect_error(infer(fit, type = "mbco"), "estimator.*ML")
  for (args in list(list(estimator = "MLR"), list(likelihood = "wishart"),
    list(control = list(iter.max = 1)), list(auto.cov.y = FALSE))) {
    expect_error(sem_public_direct(args = args), names(args), fixed = TRUE)
  }
  expect_error(mbco_d4(sem_public_imps, model = "M ~ a*X; Y ~ b*M; a*b == 0",
    treatment = "X", mediator = "M", outcome = "Y"), "completeness")
})

test_that("public stored latent and defined-parameter models remain usable", {
  d <- lavaan::HolzingerSwineford1939
  latent <- mbco_d4(list(d, d),
    model = "M =~ x4 + x5 + x6; M ~ x1; x9 ~ M + x1",
    treatment = "x1", mediator = "M", outcome = "x9")
  expect_true(is.finite(latent[["p"]]))
  expect_equal(latent@k, 1)
  defined <- mbco_d4(sem_public_imps,
    model = "M ~ a*X + C; Y ~ b*M + X + C; indirect := a*b",
    treatment = "X", mediator = "M", outcome = "Y")
  expect_equal(as.vector(defined), as.vector(sem_public_direct()), tolerance = 1e-7)
})

test_that("public SEM warnings and losing-branch failures name the dataset", {
  fit <- run(sem_public_md())
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    warning("starts disagree", call. = FALSE)
    list(fit = NULL, n_obs = nrow(d), improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) list(tests = data.frame(
    constraint = paste(c(a, b), "== 0"), f = c(1, 2),
    diff_ll = c(4, 9), converged = TRUE)))
  for (invoke in list(function() sem_public_direct(), function() infer(fit, type = "mbco"))) {
    w <- capture_warnings(invoke())
    expect_length(w, 1L)
    expect_match(w, "imputation 1.*imputation 2.*stacked data.*starts disagree")
  }
  local_mocked_bindings(.mm_sem_mbco = function(fit, a, b) list(tests = data.frame(
    constraint = paste(c(a, b), "== 0"), f = c(1, 2),
    diff_ll = c(4, -1), converged = TRUE)))
  for (mode in c("own", "fixed")) {
    expect_error(sem_public_direct(ariv = mode), "imputation 1.*negative LR.*b.*Collected warnings")
    expect_error(infer(fit, type = "mbco", ariv = mode), "imputation 1.*negative LR.*b")
  }
})
