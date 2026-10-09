# The lavaan log-likelihood provider for D4-stacked MBCO
# (SPEC-sem-mbco-2026-10-08.md, T2: observed-variable models).

skip_if_not_installed("mice")

make_imps <- function(K = 4, n = 120, a = 0.6, b = 0.15, seed = 300) {
  lapply(seq_len(K), function(k) {
    set.seed(seed + k)
    X <- rnorm(n)
    C <- rnorm(n)
    M <- a * X + 0.3 * C + rnorm(n)
    data.frame(X = X, M = M, Y = b * M + 0.2 * X + 0.3 * C + rnorm(n), C = C)
  })
}

MOD <- "M ~ X + C\nY ~ M + X + C"
prov <- function(model = MOD, fit_args = list()) {
  missingmed:::.mm_lav_provider(model, "X", "M", "Y", fit_args)
}
glm_d4 <- function(imps, ariv) {
  mbco_d4(imps, Y ~ M + X + C, M ~ X + C, treatment = "X", mediator = "M", ariv = ariv)
}
pool <- function(imps, ariv, provider = prov()) missingmed:::.mm_d4_pool(imps, provider, ariv)

test_that("lavaan equals the glm engine on an observed model, both branches, both ariv", {
  for (cfg in list(c(a = 0.6, b = 0.15), c(a = 0.15, b = 0.6))) { # b wins, then a wins
    imps <- make_imps(a = cfg[["a"]], b = cfg[["b"]])
    for (ariv in c("fixed", "own")) {
      got <- pool(imps, ariv)
      ref <- glm_d4(imps, ariv)
      expect_equal(as.vector(got), as.vector(ref), tolerance = 1e-8)
      # The a/b labels cancel in D4 and p; the diagnostics do not.
      expect_identical(got@stacked_branch, ref@stacked_branch)
      expect_equal(got@p_branch_a, ref@p_branch_a)
      expect_equal(got@k, ref@k)
    }
  }
  expect_identical(pool(make_imps(a = 0.6, b = 0.15), "fixed")@stacked_branch, "b")
  expect_identical(pool(make_imps(a = 0.15, b = 0.6), "fixed")@stacked_branch, "a")
})

test_that("each null equals the 0* syntax oracle (catches swapped rows)", {
  d <- make_imps(K = 1)[[1]]
  t3 <- prov()(d)
  ll <- function(syn) as.numeric(lavaan::fitMeasures(suppressWarnings(lavaan::sem(syn, data = d)), "logl"))
  expect_equal(t3[["full"]], ll(MOD), tolerance = 1e-9)
  expect_equal(t3[["a"]], ll("M ~ 0*X + C\nY ~ M + X + C"), tolerance = 1e-9)
  expect_equal(t3[["b"]], ll("M ~ X + C\nY ~ 0*M + X + C"), tolerance = 1e-9)
  expect_gt(abs(t3[["a"]] - t3[["b"]]), 1) # the two nulls differ, so a swap shows
  expect_equal(unname(t3[c("k_a", "k_b")]), c(1, 1))
})

test_that("K identical copies reproduce the single-dataset LRT with r4 = 0", {
  d <- make_imps(K = 1)[[1]]
  r <- pool(list(d, d, d), "fixed")
  full <- suppressWarnings(lavaan::sem(MOD, data = d))
  win <- if (r@stacked_branch == "a") "M ~ 0*X + C\nY ~ M + X + C" else "M ~ X + C\nY ~ 0*M + X + C"
  lrt <- lavaan::lavTestLRT(full, suppressWarnings(lavaan::sem(win, data = d)))
  expect_equal(unname(r["D4"]), lrt[["Chisq diff"]][2], tolerance = 1e-6)
  expect_equal(unname(r["r4"]), 0)
})

test_that("a model without exactly one a path or one b path is refused before pooling", {
  imps <- make_imps()
  expect_error(pool(imps, "fixed", prov("M ~ C\nY ~ M + X + C")), "exactly one `M ~ X`")
  expect_error(pool(imps, "fixed", prov("M ~ X + C\nY ~ X + C")), "exactly one `Y ~ M`")
})

test_that("a non-converged lavaan fit refuses, naming dataset and fit", {
  imps <- make_imps()
  p <- prov(fit_args = list(control = list(iter.max = 1)))
  # With iter.max = 1 the full fit converges but the a = 0 null does not, so the
  # message names that branch; every branch label is checked with .mm_lav_ll() below.
  expect_error(pool(imps, "fixed", p), "imputation 1.*the a = 0 lavaan model did not converge")
})

test_that("an explicit ML estimator in fit_args gives the same result", {
  imps <- make_imps()
  # Same statistic whether or not the (default) estimator is spelled out.
  expect_equal(
    as.vector(pool(imps, "fixed", prov(fit_args = list(estimator = "ML")))),
    as.vector(pool(imps, "fixed")), tolerance = 1e-10
  )
})

# ---- latent mediator (T3) ----------------------------------------------------

make_lat <- function(K = 3, n = 300, seed = 400, direct = 0) {
  lapply(seq_len(K), function(k) {
    set.seed(seed + k)
    X <- rnorm(n)
    L <- 0.6 * X + rnorm(n)
    d <- data.frame(
      X = X, m1 = L + rnorm(n, 0, 0.5), m2 = 0.8 * L + rnorm(n, 0, 0.5),
      m3 = 0.7 * L + rnorm(n, 0, 0.5)
    )
    d$Y <- 0.2 * X + 0.25 * L + direct * d$m1 + rnorm(n)
    d
  })
}
LAT <- "Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ Ml + X"
lat_prov <- function(model = LAT) missingmed:::.mm_lav_provider(model, "X", "Ml", "Y")

test_that("latent mediator: each null equals the 0* oracle, k = 1 on both branches", {
  d <- make_lat(K = 1)[[1]]
  t3 <- lat_prov()(d)
  ll <- function(syn) as.numeric(lavaan::fitMeasures(suppressWarnings(lavaan::sem(syn, data = d)), "logl"))
  expect_equal(t3[["full"]], ll(LAT), tolerance = 1e-9)
  expect_equal(t3[["a"]], ll("Ml =~ m1 + m2 + m3\nMl ~ 0*X\nY ~ Ml + X"), tolerance = 1e-9)
  expect_equal(t3[["b"]], ll("Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ 0*Ml + X"), tolerance = 1e-9)
  expect_equal(unname(t3[c("k_a", "k_b")]), c(1, 1)) # measurement model untouched
})

test_that("latent mediator: a direct Y ~ indicator row stays free (S3 as amended)", {
  d <- make_lat(K = 1, direct = 0.3)[[1]]
  mod <- "Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ Ml + X + m1"
  t3 <- lat_prov(mod)(d)
  expect_equal(unname(t3[c("k_a", "k_b")]), c(1, 1))
  ll <- function(syn) as.numeric(lavaan::fitMeasures(suppressWarnings(lavaan::sem(syn, data = d)), "logl"))
  # b = 0 fixes only Y ~ Ml; the direct m1 effect remains estimated.
  expect_equal(t3[["b"]], ll("Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ 0*Ml + X + m1"), tolerance = 1e-9)
  # A null that also fixed Y ~ m1 would give a different (lower) log-likelihood.
  expect_gt(t3[["b"]] - ll("Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ 0*Ml + X + 0*m1"), 1)
})

test_that("a bare lavaanify() table is not the table sem() fits (the trap)", {
  d <- make_lat(K = 1)[[1]]
  full <- suppressWarnings(lavaan::sem(LAT, data = d))
  bare <- lavaan::lavaanify(LAT, auto = TRUE)
  expect_gt(sum(bare$free > 0), lavaan::lavInspect(full, "npar"))
})

test_that("latent mediator: pooling runs, with finite D4 and p", {
  r <- missingmed:::.mm_d4_pool(make_lat(), lat_prov(), "fixed")
  expect_true(is.finite(r["p"]))
  expect_equal(r@k, 1)
})

# ---- refusals and warnings (T4) ----------------------------------------------

lav_md <- function(fit_args = list(), method = "mi") {
  imp <- mice::mice(
    {
      d <- make_imps(K = 1, n = 100)[[1]]
      d$M[1:10] <- NA
      d
    },
    m = 2, maxit = 1, method = "norm", printFlag = FALSE, seed = 1
  )
  set_md_mediation(imp,
    model = MOD, treatment = "X", mediator = "M", outcome = "Y",
    engine = "lavaan", fit_args = fit_args
  )
}

test_that("unsupported options are refused before any fit, naming the option", {
  for (est in c("MLR", "MLM", "WLSMV")) {
    expect_error(
      missingmed:::.mm_lav_check_mbco(lav_md(list(estimator = est))),
      paste0("supports estimator = \"ML\" only.*\"", est, "\"")
    )
  }
  # End to end: an MLR fit runs, then MBCO refuses.
  expect_error(infer(run(lav_md(list(estimator = "MLR"))), type = "mbco"), "estimator = \"ML\" only")
  expect_error(missingmed:::.mm_lav_check_mbco(lav_md(list(group = "X"))), "`group`")
  expect_error(missingmed:::.mm_lav_check_mbco(lav_md(list(sampling.weights = "C"))), "sampling.weights")
  expect_error(missingmed:::.mm_lav_check_mbco(lav_md(list(ordered = "Y"))), "`ordered`")
  expect_silent(missingmed:::.mm_lav_check_mbco(lav_md(list(estimator = "ML"))))
})

test_that("a model lacking the a or b path is refused (before any imputation is fit)", {
  imp <- mice::mice(make_imps(K = 1, n = 80)[[1]], m = 2, maxit = 1, printFlag = FALSE, seed = 1)
  # set_md_mediation() already refuses it; the provider's own check is the
  # second line (see the provider tests above).
  expect_error(
    set_md_mediation(imp,
      model = "M ~ C\nY ~ M + X + C", treatment = "X", mediator = "M", outcome = "Y",
      engine = "lavaan"
    ),
    "no regression of the mediator on the treatment"
  )
})

test_that("an improper solution warns once, naming the datasets, and proceeds", {
  imps <- make_imps()
  p <- function(d) {
    out <- prov()(d)
    if (nrow(d) > nrow(imps[[1]])) attr(out, "improper") <- "b = 0" # the stacked fit
    out
  }
  p2 <- function(d) {
    out <- p(d)
    if (isTRUE(all.equal(d$Y, imps[[2]]$Y))) attr(out, "improper") <- c("full", "a = 0")
    out
  }
  w <- testthat::capture_warnings(r <- missingmed:::.mm_d4_pool(imps, p2, "fixed"))
  expect_length(w, 1L)
  expect_match(w, "improper solution")
  expect_match(w, "imputation 2 \\(full, a = 0\\)")
  expect_match(w, "the stacked data \\(b = 0\\)")
  expect_true(is.finite(r["p"]))
})

# ---- mbco_d4(model = ) (T6) ---------------------------------------------------

test_that("mbco_d4(model = ) equals infer(type = 'mbco') on the same imputed data", {
  imp <- mice::mice(
    {
      d <- make_imps(K = 1, n = 100)[[1]]
      d$M[1:12] <- NA
      d
    },
    m = 3, maxit = 1, method = "norm", printFlag = FALSE, seed = 3
  )
  md <- set_md_mediation(imp,
    model = MOD, treatment = "X", mediator = "M", outcome = "Y", engine = "lavaan"
  )
  for (ariv in c("fixed", "own")) {
    via_infer <- infer(run(md), type = "mbco", ariv = ariv)
    direct <- mbco_d4(mice::complete(imp, "all"),
      model = MOD, treatment = "X", mediator = "M", outcome = "Y", ariv = ariv
    )
    expect_equal(as.vector(direct), as.vector(via_infer), tolerance = 1e-12)
    expect_identical(direct@stacked_branch, via_infer@stacked_branch)
  }
})

test_that("mbco_d4(model = ) accepts a latent mediator on a plain implist", {
  r <- mbco_d4(make_lat(), model = LAT, treatment = "X", mediator = "Ml", outcome = "Y")
  expect_s3_class(r, "missingmed::MbcoMIResult")
  expect_true(is.finite(r["p"]))
  expect_equal(r@k, 1)
})

test_that("mbco_d4(model = ) is exclusive with the formula and family arguments", {
  imps <- make_imps()
  expect_error(
    mbco_d4(imps, Y ~ M + X, M ~ X, model = MOD, treatment = "X", mediator = "M", outcome = "Y"),
    "cannot be combined with `formula_y`, `formula_m`"
  )
  expect_error(
    mbco_d4(imps, model = MOD, family_y = stats::binomial(), treatment = "X", mediator = "M", outcome = "Y"),
    "cannot be combined with `family_y`"
  )
  expect_error(
    mbco_d4(imps, model = MOD, treatment = "X", mediator = "M"),
    "`outcome` .* is required"
  )
  expect_error(
    mbco_d4(imps, Y ~ M + X, M ~ X, treatment = "X", mediator = "M", outcome = "Y"),
    "apply to `model`"
  )
  expect_error(
    mbco_d4(imps, model = MOD, treatment = "X", mediator = "M", outcome = "Y",
      fit_args = list(estimator = "MLR")),
    "estimator = \"ML\" only"
  )
})

test_that("the glm form of mbco_d4() is unchanged by the new arguments", {
  imps <- make_imps()
  expect_equal(as.vector(glm_d4(imps, "fixed")),
    as.vector(mbco_d4(imps, Y ~ M + X + C, M ~ X + C, treatment = "X", mediator = "M")))
})

# ---- defined parameters, labels, fit_args, fixed paths, edge cases (review of #56) ----

dd1 <- function() make_imps(K = 1)[[1]]
sem_ll <- function(syn, d, fa = list()) {
  as.numeric(lavaan::fitMeasures(suppressWarnings(do.call(lavaan::sem, c(list(syn, data = d), fa))), "logl"))
}

test_that("a model with a `:=` defined indirect effect gives the same test as without it", {
  imps <- make_imps()
  withdef <- "M ~ a*X + C\nY ~ b*M + cp*X + C\nab := a*b"
  without <- "M ~ a*X + C\nY ~ b*M + cp*X + C"
  a <- mbco_d4(imps, model = withdef, treatment = "X", mediator = "M", outcome = "Y")
  b <- mbco_d4(imps, model = without, treatment = "X", mediator = "M", outcome = "Y")
  expect_equal(as.vector(a), as.vector(b), tolerance = 1e-10)
  expect_equal(a@k, 1)
  # ... and through infer() on a lavaan fit
  imp <- mice::mice(
    {
      d <- dd1()
      d$M[1:12] <- NA
      d
    },
    m = 2, maxit = 1, method = "norm", printFlag = FALSE, seed = 3
  )
  md <- set_md_mediation(imp, model = withdef, treatment = "X", mediator = "M",
    outcome = "Y", engine = "lavaan")
  expect_true(is.finite(infer(run(md), type = "mbco")["p"]))
})

test_that("labelled paths and an equality constraint give the right nulls", {
  d <- dd1()
  # a shared label forces the partner path to the same value, so nulling one
  # path nulls both: the oracle fixes both, and k stays 1 (one free parameter fewer).
  t3 <- missingmed:::.mm_lav_provider("M ~ p*X + C\nY ~ p*M + X + C", "X", "M", "Y")(d)
  expect_equal(t3[["a"]], sem_ll("M ~ 0*X + C\nY ~ 0*M + X + C", d), tolerance = 1e-9)
  expect_equal(unname(t3[c("k_a", "k_b")]), c(1, 1))
})

test_that("fit_args that change the likelihood reach the null refits (oracle: sem() with 0*)", {
  d <- dd1()
  for (fa in list(list(fixed.x = FALSE), list(likelihood = "wishart"), list(conditional.x = TRUE))) {
    t3 <- missingmed:::.mm_lav_provider(MOD, "X", "M", "Y", fa)(d)
    expect_equal(t3[["full"]], sem_ll(MOD, d, fa), tolerance = 1e-9, info = names(fa))
    expect_equal(t3[["a"]], sem_ll("M ~ 0*X + C\nY ~ M + X + C", d, fa), tolerance = 1e-9, info = names(fa))
    expect_equal(t3[["b"]], sem_ll("M ~ X + C\nY ~ 0*M + X + C", d, fa), tolerance = 1e-9, info = names(fa))
  }
  # With fixed.x = FALSE the result is a sensible LRT, not a negative statistic.
  r <- mbco_d4(make_imps(), model = MOD, treatment = "X", mediator = "M", outcome = "Y",
    fit_args = list(fixed.x = FALSE))
  expect_gt(r["d_S"], 0)
  expect_equal(as.vector(r), as.vector(pool(make_imps(), "fixed")), tolerance = 1e-8)
})

test_that("a path fixed in the syntax is refused: there is no parameter to test", {
  imps <- make_imps()
  for (m in c("M ~ 0.5*X + C\nY ~ M + X + C", "M ~ 0*X + C\nY ~ M + X + C")) {
    expect_error(
      mbco_d4(imps, model = m, treatment = "X", mediator = "M", outcome = "Y"),
      "`M ~ X` path \\(the a path\\) is fixed"
    )
  }
  expect_error(
    mbco_d4(imps, model = "M ~ X + C\nY ~ 0*M + X + C", treatment = "X", mediator = "M", outcome = "Y"),
    "`Y ~ M` path \\(the b path\\) is fixed"
  )
})

test_that("an empty implist reports the imputation count, not a subscript error", {
  expect_error(
    mbco_d4(list(), model = MOD, treatment = "X", mediator = "M", outcome = "Y"),
    "at least 2 imputations"
  )
  expect_error(mbco_d4(list(), Y ~ M + X, M ~ X, treatment = "X", mediator = "M"), "at least 2 imputations")
})

test_that("a null-branch non-convergence names the branch", {
  d <- make_lat(K = 1)[[1]]
  bad <- suppressWarnings(lavaan::sem(LAT, data = d, control = list(iter.max = 1)))
  expect_false(lavaan::lavInspect(bad, "converged"))
  expect_error(missingmed:::.mm_lav_ll(bad, "a = 0"), "the a = 0 lavaan model did not converge")
  expect_error(missingmed:::.mm_lav_ll(bad, "b = 0"), "the b = 0 lavaan model did not converge")
})

test_that("a real improper solution is detected, warned about once, and the test proceeds", {
  # Two near-perfect indicators and a pure-noise one at n = 40: lavaan converges
  # to a boundary (negative variance) solution in all three fits (seeds 2-4).
  imps <- lapply(2:4, function(s) {
    set.seed(s)
    n <- 40
    L <- rnorm(n)
    dd <- data.frame(X = rnorm(n))
    dd$m1 <- L + rnorm(n, 0, 0.05)
    dd$m2 <- L + rnorm(n, 0, 0.05)
    dd$m3 <- rnorm(n)
    dd$Y <- 0.3 * L + rnorm(n)
    dd
  })
  prov <- missingmed:::.mm_lav_provider(LAT, "X", "Ml", "Y")
  expect_true(length(attr(prov(imps[[1]]), "improper")) > 0L)
  w <- testthat::capture_warnings(r <- missingmed:::.mm_d4_pool(imps, prov, "fixed"))
  expect_length(w, 1L)
  expect_match(w, "improper solution")
  expect_match(w, "imputation 1")
  expect_true(is.finite(r["p"]))
})
