# MLR for lavaan MBCO: Satorra-Bentler (2001) scaled difference per dataset, D4 on
# the naive LRTs, divided by the mean per-imputation scaling correction of the
# winning branch (SPEC-sem-mbco-2026-10-08.md, T7). The T8b gate FAILED (section
# 12), so MLR is refused publicly: these tests exercise the internal machinery
# the gate harness uses, with options(missingmed.internal_mlr = TRUE), plus the
# refusal itself.

skip_if_not_installed("mice")

nn_imps <- function(K = 4, n = 200, a = 0.15, b = 0.5, seed = 700) {
  lapply(seq_len(K), function(k) {
    set.seed(seed + k)
    e <- function() (stats::rchisq(n, 4) - 4) / sqrt(8)
    X <- e()
    M <- a * X + e()
    data.frame(X = X, M = M, Y = b * M + 0.2 * X + e())
  })
}

MOD2 <- "M ~ X\nY ~ M + X"

# Lift the public MLR refusal for the calling test only.
allow_internal_mlr <- function(env = parent.frame()) {
  old <- options(missingmed.internal_mlr = TRUE)
  do.call(on.exit, list(substitute(options(old)), add = TRUE), envir = env)
  invisible(old)
}
mlr_prov <- function() {
  missingmed:::.mm_lav_provider(MOD2, "X", "M", "Y", list(estimator = "MLR"))
}

test_that("the MLR provider adds scaling corrections; the ML provider is unchanged", {
  d <- nn_imps(K = 1)[[1]]
  ml <- missingmed:::.mm_lav_provider(MOD2, "X", "M", "Y")(d)
  expect_identical(names(ml), c("full", "a", "b", "k_a", "k_b"))
  r <- mlr_prov()(d)
  expect_identical(names(r), c("full", "a", "b", "k_a", "k_b", "cd_a", "cd_b"))
  expect_true(all(is.finite(r[c("cd_a", "cd_b")])) && all(r[c("cd_a", "cd_b")] > 0))
  # Same likelihoods as ML: only the test statistic is scaled.
  expect_equal(r[c("full", "a", "b")], ml[c("full", "a", "b")], tolerance = 1e-6)
})

test_that("cd equals naive LRT / scaled-difference LRT from lavTestLRT (SB 2001)", {
  d <- nn_imps(K = 1)[[1]]
  r <- mlr_prov()(d)
  full <- suppressWarnings(lavaan::sem(MOD2, d, estimator = "MLR"))
  for (nm in c("a", "b")) {
    syn <- if (nm == "a") "M ~ 0*X\nY ~ M + X" else "M ~ X\nY ~ 0*M + X"
    null <- suppressWarnings(lavaan::sem(syn, d, estimator = "MLR"))
    lr <- suppressWarnings(lavaan::lavTestLRT(full, null, method = "satorra.bentler.2001"))
    naive <- 2 * (r[["full"]] - r[[nm]])
    expect_equal(unname(r[[paste0("cd_", nm)]]), naive / lr[["Chisq diff"]][2], tolerance = 1e-6)
  }
})

test_that("the MLR provider pins observed information unless the user chose (se = 'none' would flip it)", {
  d <- nn_imps(K = 1)[[1]]
  obs <- mlr_prov()(d)
  exp <- missingmed:::.mm_lav_provider(MOD2, "X", "M", "Y",
    list(estimator = "MLR", information = "expected"))(d)
  expect_gt(abs(obs[["cd_a"]] - exp[["cd_a"]]), 1e-3)
  full <- suppressWarnings(lavaan::sem(MOD2, d, estimator = "MLR", information = "expected"))
  null <- suppressWarnings(lavaan::sem("M ~ 0*X\nY ~ M + X", d, estimator = "MLR", information = "expected"))
  lr <- suppressWarnings(lavaan::lavTestLRT(full, null, method = "satorra.bentler.2001"))
  expect_equal(unname(exp[["cd_a"]]), 2 * (exp[["full"]] - exp[["a"]]) / lr[["Chisq diff"]][2],
    tolerance = 1e-6)
})

test_that(".mm_scaling_cd and .mm_check_cd are the SB 2001 formula and its guard", {
  # (d0 c0 - d1 c1) / (d0 - d1); a saturated full model (df 0) has no c1.
  expect_equal(missingmed:::.mm_scaling_cd(c0 = 1.2, df0 = 1, c1 = NA_real_, df1 = 0), 1.2)
  expect_equal(missingmed:::.mm_scaling_cd(c0 = 1.1, df0 = 4, c1 = 1.2, df1 = 2), (4.4 - 2.4) / 2)
  expect_silent(missingmed:::.mm_check_cd(0.9, "a = 0"))
  for (bad in c(-0.1, 0, NA_real_, Inf)) {
    expect_error(missingmed:::.mm_check_cd(bad, "a = 0"), "scaled difference.*a = 0")
  }
})

test_that("pooling divides D4 by the mean cd of the winning branch (K identical copies)", {
  # r4 = 0 for identical imputations, so D4 = naive / k, and the scaled D4 is
  # naive / cd with p from F(k, Inf): an oracle that does not re-use the pool.
  d <- data.frame(x = 1:5)
  # The stacked data has K times the rows, so its log-likelihoods are K times
  # one dataset's (d_S = LRT_stacked / K then equals the per-imputation LRT).
  stub <- function(cd_a, cd_b) {
    function(d) {
      f <- nrow(d) / 5
      c(full = -100 * f, a = -104 * f, b = -110 * f, k_a = 1, k_b = 1, cd_a = cd_a, cd_b = cd_b)
    }
  }
  r <- missingmed:::.mm_d4_pool(list(d, d, d), stub(0.8, 1.4), "fixed") # a wins (-104 > -110)
  naive <- 2 * (-100 - -104)
  expect_equal(unname(r["D4"]), naive / 0.8, tolerance = 1e-9)
  expect_equal(unname(r["p"]), stats::pchisq(naive / 0.8, 1, lower.tail = FALSE), tolerance = 1e-8)
  expect_equal(r@scaling, 0.8)
  # The b branch's cd is not used when a wins.
  r2 <- missingmed:::.mm_d4_pool(list(d, d, d), stub(0.8, 99), "fixed")
  expect_equal(unname(r2["D4"]), unname(r["D4"]))
})

test_that("the mean is over per-imputation cd of the stacked branch (fixed) or each own branch (own)", {
  K <- 3
  imps <- lapply(1:K, function(i) data.frame(tag = i, x = 1:5))
  cds <- c(0.7, 0.9, 1.1)
  prov <- function(d) {
    f <- nrow(d) / 5
    cd <- if (f > 1) 1 else cds[d$tag[1]] # the stacked fit's own cd is not used
    c(full = -100 * f, a = -104 * f, b = -110 * f, k_a = 1, k_b = 1, cd_a = cd, cd_b = 5)
  }
  for (ariv in c("fixed", "own")) {
    r <- missingmed:::.mm_d4_pool(imps, prov, ariv)
    expect_equal(r@scaling, mean(cds), info = ariv)
    expect_equal(unname(r["D4"]), 2 * 4 / mean(cds), tolerance = 1e-9, info = ariv)
  }
})

test_that("a result without scaling (ML) has @scaling NA and an unchanged D4", {
  d <- nn_imps(K = 1)[[1]]
  imps <- list(d, d, d)
  r <- missingmed:::.mm_d4_pool(imps, missingmed:::.mm_lav_provider(MOD2, "X", "M", "Y"), "fixed")
  expect_true(is.na(r@scaling))
})

test_that("only the corrections that enter the statistic must be usable", {
  d <- data.frame(x = 1:5)
  # a wins (-104 > -110): a bad cd_b is unused, so the statistic is defined.
  unused_b <- function(d) {
    f <- nrow(d) / 5
    c(full = -100 * f, a = -104 * f, b = -110 * f, k_a = 1, k_b = 1, cd_a = 0.8, cd_b = -0.2)
  }
  r <- missingmed:::.mm_d4_pool(list(d, d, d), unused_b, "fixed")
  expect_equal(unname(r["D4"]), 2 * 4 / 0.8, tolerance = 1e-9)
  # The stacked fit's own corrections are never used either.
  bad_stacked <- function(d) {
    f <- nrow(d) / 5
    c(full = -100 * f, a = -104 * f, b = -110 * f, k_a = 1, k_b = 1,
      cd_a = if (f > 1) -1 else 0.8, cd_b = 1)
  }
  expect_equal(unname(missingmed:::.mm_d4_pool(list(d, d, d), bad_stacked, "own")["D4"]), 2 * 4 / 0.8,
    tolerance = 1e-9)
  # A bad correction on the USED branch of one imputation refuses, naming it.
  one_bad <- function(d) {
    f <- nrow(d) / 5
    c(full = -100 * f, a = -104 * f, b = -110 * f, k_a = 1, k_b = 1,
      cd_a = if (f == 1 && d$tag[1] == 2) -0.3 else 0.8, cd_b = 1)
  }
  imps <- lapply(1:3, function(i) data.frame(tag = i, x = 1:5))
  expect_error(missingmed:::.mm_d4_pool(imps, one_bad, "fixed"), "imputation 2.*scaled difference.*a = 0")
})

test_that("a non-positive cd from the provider refuses, naming the dataset", {
  d <- data.frame(x = 1:5)
  bad <- function(d) c(full = -100, a = -104, b = -110, k_a = 1, k_b = 1, cd_a = -0.2, cd_b = 1)
  expect_error(missingmed:::.mm_d4_pool(list(d, d), bad, "fixed"), "imputation 1.*scaled difference")
})

test_that("MLR, MLM and WLSMV are refused publicly; MLR only passes behind the internal option", {
  fa <- function(est) {
    mice::mice(nn_imps(K = 1, n = 100)[[1]], m = 2, maxit = 1, method = "norm", printFlag = FALSE, seed = 1) |>
      set_md_mediation(model = MOD2, treatment = "X", mediator = "M", outcome = "Y",
        engine = "lavaan", fit_args = list(estimator = est))
  }
  for (est in c("MLR", "mlr", "MLM", "WLSMV")) {
    expect_error(missingmed:::.mm_lav_check_mbco(fa(est)), "supports estimator = \"ML\" only", info = est)
  }
  expect_error(missingmed:::.mm_lav_check_mbco(fa("MLR")), "section 12")
  expect_error(missingmed:::.mm_lav_check_mbco(fa("MLM")), "Use estimator = \"ML\"")
  # The internal option lifts the refusal for MLR only.
  allow_internal_mlr()
  expect_silent(missingmed:::.mm_lav_check_mbco(fa("MLR")))
  expect_error(missingmed:::.mm_lav_check_mbco(fa("MLM")), "supports estimator = \"ML\" only")
})

test_that("infer(type = 'mbco') runs end to end under MLR and mbco_d4(model = ) agrees", {
  allow_internal_mlr()
  local({
    op <- options(missingmed.internal_mlr = FALSE)
    on.exit(options(op))
    expect_error(
      mbco_d4(nn_imps(K = 2), model = MOD2, treatment = "X", mediator = "M", outcome = "Y",
        fit_args = list(estimator = "MLR")),
      "section 12"
    )
  })
  set.seed(11)
  d <- nn_imps(K = 1, n = 250, a = 0.3, b = 0.4)[[1]]
  d$M[stats::runif(nrow(d)) < stats::plogis(-0.5 + d$X)] <- NA
  imp <- mice::mice(d, m = 6, maxit = 2, method = "norm", printFlag = FALSE, seed = 2)
  md <- set_md_mediation(imp, model = MOD2, treatment = "X", mediator = "M", outcome = "Y",
    engine = "lavaan", fit_args = list(estimator = "MLR"))
  fit <- suppressWarnings(run(md))
  r <- infer(fit, type = "mbco")
  expect_true(S7::S7_inherits(r, MbcoMIResult))
  expect_true(is.finite(r@scaling) && r@scaling > 0)
  expect_true(r[["p"]] >= 0 && r[["p"]] <= 1)
  r2 <- mbco_d4(mice::complete(imp, "all"), model = MOD2, treatment = "X", mediator = "M",
    outcome = "Y", fit_args = list(estimator = "MLR"))
  expect_equal(as.vector(r2), as.vector(r), tolerance = 1e-8)
  expect_equal(r2@scaling, r@scaling, tolerance = 1e-8)
})
