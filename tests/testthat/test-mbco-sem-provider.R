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
