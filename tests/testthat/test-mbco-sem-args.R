fit_sem_calls_explicit <- function(exprs) {
  found <- character()
  walk <- function(e) {
    if (is.call(e)) {
      f <- e[[1L]]
      if (identical(f, quote(fit_sem)) || identical(f, quote(medfit::fit_sem))) {
        found <<- c(found, if (all(c("fixed_x", "meanstructure") %in% names(e))) "ok" else "bad")
      }
      for (i in seq_along(e)) {
        if (!identical(e[[i]], quote(expr = ))) walk(e[[i]])
      }
    }
  }
  for (e in exprs) walk(e)
  found
}

test_that("every fit_sem() call in the SEM MBCO adapter passes fixed_x and meanstructure", {
  src <- test_path("..", "..", "R", "mbco_sem.R")
  skip_if_not(file.exists(src), "package source not available")
  found <- fit_sem_calls_explicit(parse(src, keep.source = FALSE))
  expect_gte(length(found), 2L)
  expect_true(all(found == "ok"))
  # Planted defect: the form before medfit 0.14.0 must be reported.
  old <- parse(text = "medfit::fit_sem(model, d, fixed_x = FALSE)", keep.source = FALSE)
  expect_identical(fit_sem_calls_explicit(old), "bad")
})

test_that("SEM fit_args accepts exactly the approved ignored options", {
  check <- missingmed:::.mm_sem_check_args
  expect_silent(check(list()))
  allowed <- list(estimator = "ML", std.lv = TRUE, std.ov = TRUE, fixed.x = TRUE,
    conditional.x = TRUE, meanstructure = FALSE, information = "observed",
    missing = "listwise", se = "none", test = "none")
  for (nm in names(allowed)) expect_silent(check(allowed[nm]))
  expect_silent(check(allowed))
  expect_silent(check(list(ESTIMATOR = "ml", std_lv = TRUE, fixed_x = TRUE)))
})

test_that("SEM fit_args refuses unknown and likelihood-changing options by name", {
  check <- missingmed:::.mm_sem_check_args
  for (nm in c("auto.var", "auto.fix.first", "auto.cov.y", "orthogonal",
    "orthogonal.x", "int.ov.free", "int.lv.free", "control", "group", "ordered",
    "sampling.weights", "likelihood", "n_starts", "unknown", "est")) {
    expect_error(check(setNames(list(FALSE), nm)), nm, fixed = TRUE)
  }
  expect_error(check(list(likelihood = "wishart")), "likelihood")
  for (value in list("MLR", "MLM", "WLSMV", NA_character_, character(), c("ML", "MLR"),
    NULL, 1, TRUE)) {
    expect_error(check(list(estimator = value)), "estimator")
  }
  for (value in list(NULL, TRUE, "ML", data.frame(x = 1), list(TRUE),
    setNames(list(TRUE), ""), setNames(list(TRUE), NA_character_))) {
    expect_error(check(value), "fit_args")
  }
  expect_error(check(list(fixed.x = TRUE, fixed_x = FALSE)), "Duplicate.*fixed_x")
})

test_that("ignored SEM options leave stored-data likelihood branches unchanged", {
  skip_if_not_installed("medfit", "0.10.0")
  cases <- list(
    list(model = "M ~ X + C; Y ~ M + X + C",
      d = setNames(iris[1:4], c("X", "M", "Y", "C")), x = "X", y = "Y"),
    list(model = "M =~ x4 + x5 + x6; M ~ x1; x9 ~ M + x1",
      d = lavaan::HolzingerSwineford1939, x = "x1", y = "x9")
  )
  args <- list(estimator = "ML", std.lv = TRUE, std.ov = TRUE, fixed.x = TRUE,
    conditional.x = TRUE, meanstructure = FALSE, information = "observed",
    missing = "listwise", se = "none", test = "none")
  for (case in cases) {
    provider <- function(fa) missingmed:::.mm_sem_provider(case$model, case$x,
      "M", case$y, fa)(case$d)
    expect_equal(provider(args), provider(list()), tolerance = 0)
  }
})

test_that("SEM options never reach the dependency adapter and refusals precede fits", {
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    stop("adapter reached with model and data only")
  })
  make <- function(args) missingmed:::.mm_sem_provider("M ~ X; Y ~ M", "X", "M", "Y", args)
  expect_error(make(list(fixed.x = TRUE))(iris), "adapter reached")
  expect_error(make(list(control = list(iter.max = 5000))), "control")
})

test_that("the real SEM adapter always supplies fixed_x FALSE", {
  skip_if_not_installed("medfit", "0.10.0")
  original <- medfit::fit_sem
  seen <- list()
  local_mocked_bindings(fit_sem = function(model, data, ...) {
    seen[[length(seen) + 1L]] <<- list(...)
    original(model, data, ...)
  }, .package = "medfit")
  d <- setNames(iris[1:4], c("X", "M", "Y", "C"))
  p <- missingmed:::.mm_sem_provider("M ~ X + C; Y ~ M + X + C", "X", "M", "Y",
    list(fixed.x = TRUE))
  p(d)
  expect_gte(length(seen), 1L)
  expect_true(all(vapply(seen, function(x) identical(x$fixed_x, FALSE), NA)))
})
