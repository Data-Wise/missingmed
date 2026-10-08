# pool() and infer() with engine = "lavaan" (SPEC Q2, Q3, Q4; PLAN T3, T4).

skip_if_not_installed("mice")
skip_if_not_installed("lavaan")

gen_pl <- function(n = 250, seed = 41) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, .5)
  M <- .5 * X + .3 * C + rnorm(n)
  Y <- .2 * X + .4 * M + .3 * C + rnorm(n)
  d <- data.frame(X, C, M, Y)
  d$M[1:40] <- NA
  d
}
imp_of <- function(m) {
  mice::mice(gen_pl(), m = m, maxit = 2, method = "norm", printFlag = FALSE, seed = 5)
}
mod <- "M ~ a*X + C\nY ~ b*M + cp*X + C"
md_l <- function(im) {
  set_md_mediation(im,
    model = mod, treatment = "X", mediator = "M", outcome = "Y",
    engine = "lavaan"
  )
}
md_g <- function(im) {
  set_md_mediation(im, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M")
}
tt <- function(res) {
  t <- res@tidy_table
  rownames(t) <- t$term
  t
}

test_that("pooled a, b, c_prime equal glm (1e-6); ML SEs follow sqrt((n - p)/n) at m = 1", {
  im1 <- imp_of(1)
  l <- tt(pool(run(md_l(im1))))
  g <- tt(pool(run(md_g(im1))))
  k <- c("a", "b", "c_prime")
  expect_equal(l[k, "estimate"], g[k, "estimate"], tolerance = 1e-6)
  n <- 250
  expect_equal(l["a", "std_error"] / g["a", "std_error"], sqrt((n - 3) / n),
    tolerance = 1e-3
  )
  expect_equal(l["b", "std_error"] / g["b", "std_error"], sqrt((n - 4) / n),
    tolerance = 1e-3
  )
  im3 <- imp_of(3)
  expect_equal(tt(pool(run(md_l(im3))))[k, "estimate"],
    tt(pool(run(md_g(im3))))[k, "estimate"],
    tolerance = 1e-6
  )
})

test_that("at m = 1 df is Inf and tests match lavaan::parameterEstimates()", {
  im1 <- imp_of(1)
  l <- tt(pool(run(md_l(im1))))
  d1 <- mice::complete(im1, 1)
  pe <- lavaan::parameterEstimates(lavaan::sem(mod, d1))
  pick <- function(lhs, rhs) pe[pe$lhs == lhs & pe$op == "~" & pe$rhs == rhs, ]
  for (x in list(c("a", "M", "X"), c("b", "Y", "M"), c("cp", "Y", "X"))) {
    row <- pick(x[2], x[3])
    term <- if (x[1] == "cp") "cp" else x[1]
    expect_equal(l[term, "estimate"], row$est, tolerance = 1e-8)
    expect_equal(l[term, "std_error"], row$se, tolerance = 1e-6)
    expect_equal(l[term, "statistic"], row$z, tolerance = 1e-6)
    expect_equal(l[term, "p_value"], row$pvalue, tolerance = 1e-6)
  }
  expect_true(all(is.infinite(l$df)))
})

test_that("~~ rows keep estimate and SE, with NA statistic and p-value", {
  l <- tt(pool(run(md_l(imp_of(3)))))
  vv <- grepl("~~", rownames(l), fixed = TRUE)
  expect_true(any(vv))
  expect_true(all(is.finite(l$estimate[vv])))
  expect_true(all(is.finite(l$std_error[vv])))
  expect_true(all(is.na(l$statistic[vv])))
  expect_true(all(is.na(l$p_value[vv])))
  expect_false(anyNA(l$p_value[!vv]))
})

test_that("with m > 1 the df is Rubin's large-sample df, finite and positive", {
  l <- tt(pool(run(md_l(imp_of(4)))))
  k <- c("a", "b", "c_prime")
  expect_true(all(is.finite(l[k, "df"]) & l[k, "df"] > 0))
})

test_that("infer(type = 'mc') works on a lavaan fit and matches glm's interval", {
  im <- imp_of(3)
  set.seed(7)
  a <- infer(run(md_l(im)), type = "mc", n.mc = 20000)
  set.seed(7)
  b <- infer(run(md_g(im)), type = "mc", n.mc = 20000)
  expect_equal(a$Estimate, b$Estimate, tolerance = 1e-3)
  expect_equal(unname(a$CI), unname(b$CI), tolerance = 0.05)
})

test_that("infer(type = 'mbco') on a lavaan fit errors, naming the follow-up", {
  expect_error(infer(run(md_l(imp_of(2))), type = "mbco"), "not available for engine")
  expect_error(infer(run(md_l(imp_of(2))), type = "mbco"), "needs its own spec")
})
