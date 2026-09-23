# Rubin inference columns in the pooled tidy() table
# (docs/specs/SPEC-pooled-inference-columns-2026-09-23.md)

skip_if_not_installed("medfit")
skip_if_not_installed("mice")

gen_pool_data <- function(n = 200, seed = 1) {
  set.seed(seed)
  X <- rnorm(n)
  C <- rnorm(n)
  M <- 0.4 * X + 0.3 * C + rnorm(n)
  Y <- 0.5 * M + 0.2 * X + rnorm(n)
  d <- data.frame(X = X, C = C, M = M, Y = Y)
  d$M[sample(n, 40)] <- NA
  d$Y[sample(n, 30)] <- NA
  d
}

fit_pool <- function(m = 5, n = 200, family_m = stats::gaussian(),
                     data = gen_pool_data(n)) {
  imp <- mice::mice(data, m = m, printFlag = FALSE, seed = 2)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_m = family_m
  )
  run(md)
}

test_that("the pooled tidy table carries statistic, df, riv, fmi and p_value", {
  tt <- pool(fit_pool())@tidy_table
  expect_true(all(c("statistic", "df", "riv", "fmi", "p_value") %in% names(tt)))
  expect_true(all(is.finite(tt$p_value)))
  expect_true(all(tt$p_value >= 0 & tt$p_value <= 1))
})

test_that("df, riv and fmi match mice::pool.scalar with a per-model dfcom", {
  fit <- fit_pool(m = 5)
  tt <- pool(fit)@tidy_table
  n <- fit@per_imputation[[1]]@n_obs
  k_m <- sum(startsWith(tt$term, "m_"))
  k_y <- sum(startsWith(tt$term, "y_"))
  for (term in c("m_X", "m_C", "y_X", "y_M", "y_C")) {
    Q <- vapply(fit@per_imputation, function(x) x@estimates[[term]], 0)
    U <- vapply(fit@per_imputation, function(x) x@vcov[term, term], 0)
    k <- if (startsWith(term, "m_")) k_m else k_y
    ref <- mice::pool.scalar(Q, U, n = n, k = k)
    row <- tt[tt$term == term, ]
    expect_equal(row$df, ref$df, tolerance = 1e-10, label = paste(term, "df"))
    expect_equal(row$riv, ref$r, tolerance = 1e-10, label = paste(term, "riv"))
    expect_equal(row$fmi, ref$fmi, tolerance = 1e-10, label = paste(term, "fmi"))
  }
})

test_that("the statistic and p_value are the Wald t on the Rubin df", {
  tt <- pool(fit_pool())@tidy_table
  expect_equal(tt$statistic, tt$estimate / tt$std_error)
  expect_equal(tt$p_value, 2 * stats::pt(-abs(tt$statistic), tt$df))
})

test_that("df never exceeds the complete-data df (the df = 4802 regression)", {
  fit <- fit_pool(m = 5, n = 200)
  tt <- pool(fit)@tidy_table
  n <- fit@per_imputation[[1]]@n_obs
  dfcom_m <- n - sum(startsWith(tt$term, "m_"))
  dfcom_y <- n - sum(startsWith(tt$term, "y_"))
  expect_length(tt$df, nrow(tt))
  expect_true(all(tt$df[startsWith(tt$term, "m_")] <= dfcom_m))
  expect_true(all(tt$df[startsWith(tt$term, "y_")] <= dfcom_y))
})

test_that("a binomial mediator model uses dfcom = Inf, i.e. Rubin's 1987 df", {
  d <- gen_pool_data()
  d$M <- as.integer(d$M > 0)
  fit <- fit_pool(m = 5, family_m = stats::binomial(), data = d)
  tt <- pool(fit)@tidy_table
  for (term in c("m_X", "m_C")) {
    Q <- vapply(fit@per_imputation, function(x) x@estimates[[term]], 0)
    U <- vapply(fit@per_imputation, function(x) x@vcov[term, term], 0)
    ref <- mice::pool.scalar(Q, U) # n = Inf by default
    expect_equal(tt$df[tt$term == term], ref$df, tolerance = 1e-10)
  }
})

test_that("at m = 1 the table is the single-fit Wald test and matches summary.glm", {
  set.seed(3)
  d <- gen_pool_data()
  imp <- mice::mice(d, m = 1, printFlag = FALSE, seed = 2)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  tt <- pool(run(md))@tidy_table
  expect_true(all(tt$riv == 0))
  expect_true(all(tt$fmi == 0))
  cd <- mice::complete(imp, 1)
  ref_m <- summary(stats::glm(M ~ X + C, data = cd))$coefficients
  ref_y <- summary(stats::glm(Y ~ X + M + C, data = cd))$coefficients
  expect_equal(tt$df[tt$term == "m_X"], nrow(cd) - 3)
  expect_equal(tt$p_value[tt$term == "m_X"], ref_m["X", "Pr(>|t|)"], tolerance = 1e-8)
  expect_equal(tt$p_value[tt$term == "y_M"], ref_y["M", "Pr(>|t|)"], tolerance = 1e-8)
})

test_that("the alias rows a, b and c_prime equal their source rows in every column", {
  tt <- pool(fit_pool())@tidy_table
  cols <- setdiff(names(tt), "term")
  expect_true(all(c("df", "p_value", "fmi") %in% cols))
  for (pair in list(c("a", "m_X"), c("b", "y_M"), c("c_prime", "y_X"))) {
    expect_equal(unlist(tt[tt$term == pair[1], cols]),
      unlist(tt[tt$term == pair[2], cols]),
      ignore_attr = TRUE, label = pair[1]
    )
  }
})

test_that("an IPW fit (m = 1) reports riv = fmi = 0 and finite p-values", {
  set.seed(2026)
  n <- 600
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[plogis(-1.2 + 0.4 * d$X + 0.4 * d$C) > runif(n)] <- NA
  fit <- suppressWarnings(run(set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_trim = 0.99
  )))
  tt <- pool(fit)@tidy_table
  expect_length(tt$p_value, nrow(tt))
  expect_true(all(tt$riv == 0 & tt$fmi == 0))
  expect_true(all(is.finite(tt$p_value)))
})
