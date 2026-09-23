# MNAR sensitivity: delta-adjusted imputation across a grid.

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

gen_mnar <- function(n = 400, seed = 4) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.6 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.5 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < plogis(-1.2 + 0.5 * X + 0.5 * C)] <- NA
  d
}
md_mi <- function(m = 5, seed = 99, maxit = 5, ...) {
  # Materialise the data BEFORE calling mice(). Passing `gen_mnar(...)` inline
  # hands mice() a promise, which R forces only after mice() has called
  # set.seed(seed) -- so gen_mnar()'s own set.seed() lands afterwards and
  # silently overrides it, making the "seeded" imputation unreproducible.
  d <- gen_mnar(...)
  imp <- mice::mice(d, m = m, maxit = maxit, printFlag = FALSE, seed = seed)
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
}

test_that("delta = 0 reproduces the MAR analysis exactly", {
  # Asserted on MBCO, which is deterministic. The Monte-Carlo CI is NOT usable
  # for this check: ci_mediation_data() draws n.mc samples, so two calls on
  # identical pooled input differ by MC noise and the test would fail for a
  # reason that has nothing to do with imputation.
  md <- md_mi()
  sens <- suppressMessages(sensitivity_mnar(md, delta = 0, type = "mbco"))
  base <- infer(run(md), type = "mbco")
  expect_equal(unname(sens@rungs[[1]][["D4"]]), unname(base[["D4"]]))
  expect_equal(sens@seed, 99)
  expect_equal(sens@seed_source, "mids")
})

test_that("a monotone delta grid moves the indirect effect monotonically", {
  # Direction only. The realized shift is NOT equal to delta (see the msp test),
  # so asserting a magnitude here would be asserting the wrong thing.
  md <- md_mi()
  sens <- suppressMessages(
    sensitivity_mnar(md, delta = c(0, -0.5, -1, -1.5), n.mc = 3e3)
  )
  tb <- tidy(sens)
  expect_equal(nrow(tb), 4L)
  expect_true(all(diff(tb$estimate) < 0))
  expect_true(all(tb$conf_low < tb$conf_high))
})

test_that("the realized MSP is reported and differs from the supplied CSP", {
  # The CSP/MSP gap is the headline failure mode of this method (Tompsett et al.
  # 2018): users supply a marginal quantity where a conditional one is expected.
  # Reporting msp is how a user can see the gap rather than assume it away.
  md <- md_mi()
  sens <- suppressMessages(sensitivity_mnar(md, delta = c(0, -2), n.mc = 3e3))
  tb <- tidy(sens)
  expect_true("msp" %in% names(tb))
  expect_true(all(is.finite(tb$msp)))
  # Even at delta = 0 the MSP is non-zero: missingness depends on X and C, so
  # MAR-imputed values legitimately differ from observed ones. This alone is
  # worth surfacing -- a user reading delta = 0 as "no departure" is right about
  # the assumption but wrong about the realised marginal difference.
  expect_false(isTRUE(all.equal(tb$msp[1], 0)))
  # With a SINGLE incomplete variable the increments coincide: there is no other
  # incomplete variable for the shift to feed back through, so the CSP/MSP gap
  # in the increment is zero. The gap is a chained-equations effect, not an
  # intrinsic property of delta adjustment -- see the multivariate test below.
  expect_equal(tb$msp[2] - tb$msp[1], -2)
})

test_that("the CSP/MSP increment gap appears once a second variable is incomplete", {
  # Two incomplete variables: the shift on M re-enters Y's imputation model and
  # Y re-enters M's on the next cycle, so the realised marginal shift no longer
  # equals the supplied delta. This is the mechanism behind Tompsett et al.'s
  # warning, reproduced here so a regression in the msp computation is visible.
  d <- gen_mnar()
  d$Y[runif(nrow(d)) < plogis(-1.4 + 0.5 * d$X + 0.5 * d$C)] <- NA
  imp <- mice::mice(d, m = 4, printFlag = FALSE, seed = 21)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  sens <- suppressMessages(sensitivity_mnar(md, delta = c(0, -2), n.mc = 2e3))
  tb <- tidy(sens)
  gap <- (tb$msp[2] - tb$msp[1]) - (-2)
  expect_false(isTRUE(all.equal(gap, 0)))
})

test_that("a user's existing post entry survives re-imputation", {
  d <- gen_mnar()
  post <- mice::make.post(d)
  post["M"] <- "imp[[j]][, i] <- pmax(imp[[j]][, i], -1)"
  imp <- mice::mice(d, m = 3, post = post, printFlag = FALSE, seed = 5)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  sens <- suppressMessages(sensitivity_mnar(md, delta = 1, n.mc = 2e3))
  expect_s7_class(sens, MDSensitivityResult)
  expect_equal(nrow(tidy(sens)), 1L)
})

test_that("a data.frame grid drives one rung per row", {
  md <- md_mi()
  g <- data.frame(M = c(0, -1))
  sens <- suppressMessages(sensitivity_mnar(md, delta = g, n.mc = 2e3))
  expect_equal(nrow(tidy(sens)), 2L)
  expect_equal(sens@target, "M")
})

# ── documented refusals ─────────────────────────────────────────────────────

test_that("IPW is refused with guidance", {
  d <- gen_mnar()
  md <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw"
  )
  expect_error(sensitivity_mnar(md, delta = 1), "not available for method")
})

test_that("a fully observed target is refused, not silently a no-op", {
  md <- md_mi()
  expect_error(sensitivity_mnar(md, delta = 1, target = "C"), "no missing values")
})

test_that("an unknown target is refused", {
  md <- md_mi()
  expect_error(sensitivity_mnar(md, delta = 1, target = "nope"), "not a column")
})

test_that("a multinomial target is refused, naming the binary alternative", {
  # mice ships no NARFCS method for polyreg/polr/lda, so these stay refused.
  # Before NARFCS delegation, binary targets were refused here too.
  set.seed(8)
  n <- 300
  d <- gen_mnar(n)
  d$K <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  d$K[sample(n, 60)] <- NA
  imp <- mice::mice(d, m = 2, maxit = 2, printFlag = FALSE, seed = 8)
  expect_equal(unname(imp$method[["K"]]), "polyreg")
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  expect_error(
    sensitivity_mnar(md, delta = 1, target = "K"),
    "polyreg.*binary target imputed by 'logreg'"
  )
})

test_that("target must be NULL when delta is a data frame", {
  md <- md_mi()
  expect_error(
    sensitivity_mnar(md, delta = data.frame(M = 0), target = "M"),
    "must be NULL"
  )
})

# ── D1: mechanism is derived, not user-set ──────────────────────────────────

test_that("mechanism = 'mnar' is deprecated and ignored", {
  d <- gen_mnar()
  imp <- mice::mice(d, m = 2, printFlag = FALSE, seed = 3)
  expect_warning(
    md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
      treatment = "X", mediator = "M", mechanism = "mnar"
    ),
    "deprecated"
  )
  expect_equal(md@mechanism, "mar")
})

test_that("sensitivity_mnar stamps mechanism on the objects it creates", {
  md <- md_mi()
  expect_equal(md@mechanism, "mar")
  sens <- suppressMessages(sensitivity_mnar(md, delta = 0, type = "mbco"))
  expect_equal(sens@source@mechanism, "mar") # the original is untouched
  expect_s7_class(sens, MDSensitivityResult)
})

# ── Review fixes (PR #6 adversarial pass) ───────────────────────────────────

test_that("an unseeded mids falls back to the package default and says so", {
  d <- gen_mnar()
  imp <- mice::mice(d, m = 3, printFlag = FALSE)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  sens <- suppressMessages(sensitivity_mnar(md, delta = 0, type = "mbco"))
  expect_equal(sens@seed, 20260822L)
  expect_equal(sens@seed_source, "default")
})

test_that("delta is composed into the post expression at full precision", {
  md <- md_mi(m = 2)
  delta <- 0.123456789012
  imp <- missingmed:::.mnar_reimpute(md@data, data.frame(M = delta), seed = 1)
  expect_match(imp$post[["M"]], "0.123456789012", fixed = TRUE)
})

test_that("method_target covers every target of a multi-column delta", {
  d <- gen_mnar()
  d$Y[runif(nrow(d)) < 0.2] <- NA
  imp <- mice::mice(d, m = 3, printFlag = FALSE, seed = 7)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  sens <- suppressMessages(
    sensitivity_mnar(md, delta = data.frame(M = 0, Y = 0), type = "mbco")
  )
  expect_equal(sens@target, c("M", "Y"))
  expect_length(sens@method_target, 2L)
})

test_that("delta = 0 reproduces MAR when the baseline used a non-default maxit", {
  md <- md_mi(maxit = 12)
  sens <- suppressMessages(sensitivity_mnar(md, delta = 0, type = "mbco"))
  base <- infer(run(md), type = "mbco")
  expect_equal(unname(sens@rungs[[1]][["D4"]]), unname(base[["D4"]]))
})

test_that("a target inside a multivariate block is refused", {
  d <- gen_mnar()
  d$Y[runif(nrow(d)) < 0.2] <- NA
  imp <- mice::mice(d, m = 2, maxit = 1, printFlag = FALSE, seed = 3,
    blocks = list(MY = c("M", "Y"), X = "X", C = "C"), method = c("norm", "", ""))
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  expect_error(sensitivity_mnar(md, delta = 1), "multivariate block")
})

# ── Second review pass (PR #7) ──────────────────────────────────────────────

test_that("a maxit = 0 baseline is refused rather than returning a flat curve", {
  d <- gen_mnar()
  imp <- mice::mice(d, m = 3, maxit = 0, printFlag = FALSE, seed = 1)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  expect_error(sensitivity_mnar(md, delta = c(0, 2)), "maxit = 0")
})

test_that("a univariate block with a non-default name is accepted", {
  d <- gen_mnar()
  imp <- mice::mice(d, m = 2, maxit = 2, printFlag = FALSE, seed = 2,
    blocks = list(BM = "M", BX = "X", BY = "Y", BC = "C")
  )
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  sens <- suppressMessages(sensitivity_mnar(md, delta = c(0, 1), type = "mbco"))
  expect_length(sens@rungs, 2L)
  expect_false(isTRUE(all.equal(sens@msp[1], sens@msp[2])))
})

test_that("a genuinely multivariate block is still refused, by block membership", {
  d <- gen_mnar()
  d$Y[runif(nrow(d)) < 0.2] <- NA
  imp <- mice::mice(d, m = 2, maxit = 1, printFlag = FALSE, seed = 3,
    blocks = list(M = c("M", "Y"), X = "X", C = "C"), method = c("norm", "", "")
  )
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
  expect_error(sensitivity_mnar(md, delta = 1), "multivariate block")
})

# ── NARFCS delegation (SPEC-narfcs-delegation-2026-08-29) ───────────────────

md_norm <- function(m = 4, seed = 11, blocks = NULL, blots = NULL) {
  d <- gen_mnar()
  args <- list(d, m = m, maxit = 4, printFlag = FALSE, seed = seed)
  if (!is.null(blocks)) args$blocks <- blocks
  meth <- mice::make.method(d, blocks = blocks %||% mice::make.blocks(d))
  meth[meth != ""] <- "norm"
  args$method <- meth
  if (!is.null(blots)) args$blots <- blots
  imp <- do.call(mice::mice, args)
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M"
  )
}

test_that("a norm target is routed to mnar.norm, and the draws equal the post shift", {
  # The spec's central finding: for a constant delta on a norm target, NARFCS
  # and the post shift give IDENTICAL draws. Pinned against a direct mice()
  # post call, so the new route cannot drift from the old one unnoticed.
  md <- md_norm()
  mids <- md@data
  expect_equal(missingmed:::.mnar_route(mids, "M"), "mnar.norm")
  via_route <- missingmed:::.mnar_reimpute(mids, data.frame(M = 1.5), seed = 3)
  expect_equal(unname(via_route$method[["M"]]), "mnar.norm")
  post <- mids$post
  post["M"] <- "imp[[j]][, i] <- imp[[j]][, i] + (1.5)"
  via_post <- mice::mice(mids$data, m = mids$m, maxit = mids$iteration,
    method = mids$method, predictorMatrix = mids$predictorMatrix,
    post = post, seed = 3, printFlag = FALSE
  )
  expect_lt(max(abs(as.matrix(via_route$imp$M) - as.matrix(via_post$imp$M))), 1e-12)
  # No double shift: the routed target carries no post line of ours.
  expect_false(grepl("1.5", via_route$post[["M"]], fixed = TRUE))
})

test_that("delta = 0 on the mnar.norm route reproduces MAR exactly", {
  md <- md_norm()
  sens <- sensitivity_mnar(md, delta = 0, type = "mbco")
  base <- infer(run(md), type = "mbco")
  expect_equal(unname(sens@rungs[[1]][["D4"]]), unname(base[["D4"]]))
})

test_that("mnar.norm blots are keyed by block, and a user's entry survives", {
  # mice keys blots by BLOCK: blots = list(M = ...) under a block named "BM"
  # errors inside mice ("ums not found"). A pre-existing entry must be merged.
  bl <- list(BM = "M", BX = "X", BY = "Y", BC = "C")
  md <- md_norm(blocks = bl, blots = list(BM = list(ridge = 1e-4)))
  imp <- missingmed:::.mnar_reimpute(md@data, data.frame(M = -0.5), seed = 2)
  expect_equal(imp$blots$BM$ums, "-0.5")
  expect_equal(imp$blots$BM$ridge, 1e-4)
  expect_null(imp$blots$M)
})

test_that("a tiny delta is written without scientific notation", {
  # parse.ums() reads "1e-05" as two intercept terms and errors.
  expect_equal(missingmed:::.mnar_ums(1e-05), "0.00001")
  expect_equal(missingmed:::.mnar_ums(-2.5e-07), "-0.00000025")
  md <- md_norm(m = 2)
  expect_no_error(missingmed:::.mnar_reimpute(md@data, data.frame(M = 1e-05), seed = 1))
})

test_that("norm variants that mnar.norm would replace stay on the post route", {
  # Routing norm.nob/norm.boot/norm.predict to mnar.norm would change the
  # imputation method itself, so delta = 0 would no longer reproduce MAR.
  d <- gen_mnar()
  meth <- mice::make.method(d)
  meth["M"] <- "norm.nob"
  imp <- mice::mice(d, m = 2, maxit = 2, method = meth, printFlag = FALSE, seed = 4)
  expect_equal(missingmed:::.mnar_route(imp, "M"), "post")
  expect_equal(missingmed:::.mnar_route(md_mi(m = 2)@data, "M"), "post") # pmm
})

gen_binary_m <- function(n = 600, seed = 7) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- rbinom(n, 1, plogis(-0.2 + 1.2 * X + 0.3 * C))
  Y <- 0.2 * X + 1.0 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < plogis(-1.2 + 0.5 * X + 0.5 * C)] <- NA
  d
}
md_binary <- function(method = "logreg", m = 4, seed = 7) {
  d <- gen_binary_m()
  meth <- mice::make.method(d)
  meth["M"] <- method
  # logreg on a numeric 0/1 column warns "Type mismatch" -- benign here.
  imp <- suppressWarnings(
    mice::mice(d, m = m, maxit = 4, method = meth, printFlag = FALSE, seed = seed)
  )
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", family_m = stats::binomial()
  )
}

test_that("a binary logreg target runs through mnar.logreg; delta = 0 is MAR", {
  md <- md_binary()
  expect_equal(missingmed:::.mnar_route(md@data, "M"), "mnar.logreg")
  sens <- suppressWarnings(sensitivity_mnar(md, delta = c(0, 1, 2), type = "mbco"))
  base <- infer(run(md), type = "mbco")
  expect_equal(unname(sens@rungs[[1]][["D4"]]), unname(base[["D4"]]))
  # msp is a prevalence difference on the 0/1 scale, and it matches the MAR
  # baseline's exactly at delta = 0.
  expect_equal(sens@msp[1], missingmed:::.mnar_realized_msp(md@data, "M"))
  # A log-odds delta raises the imputed prevalence, monotonically.
  expect_true(all(diff(sens@msp) > 0))
  expect_true(all(abs(sens@msp) < 1))
})

test_that("mnar.logreg imputes 0/1 values only -- no additive shift on draws", {
  md <- md_binary(m = 2)
  imp <- suppressWarnings(
    missingmed:::.mnar_reimpute(md@data, data.frame(M = 2), seed = 1)
  )
  vals <- unique(unlist(imp$imp$M))
  expect_true(all(vals %in% c(0, 1)))
  expect_equal(imp$blots$M$ums, "2")
})

test_that("msp for a binary factor target is on the probability scale", {
  set.seed(3)
  d <- gen_mnar()
  d$B <- factor(rbinom(nrow(d), 1, 0.4), labels = c("no", "yes"))
  d$B[sample(nrow(d), 80)] <- NA
  imp <- mice::mice(d, m = 2, maxit = 2, printFlag = FALSE, seed = 3)
  expect_equal(unname(imp$method[["B"]]), "logreg")
  msp <- missingmed:::.mnar_realized_msp(imp, "B")
  expect_true(is.finite(msp))
  prev_obs <- mean(d$B[!is.na(d$B)] == "yes")
  prev_imp <- mean(unlist(lapply(imp$imp$B, function(x) x == "yes")))
  expect_equal(msp, prev_imp - prev_obs)
})

test_that("logreg.boot is refused with guidance rather than silently swapped", {
  md <- md_binary(method = "logreg.boot", m = 2)
  expect_error(sensitivity_mnar(md, delta = 1), "logreg.boot.*method = 'logreg'")
})

test_that("@mechanism_used and @scale record which path ran, per target", {
  s_pmm <- suppressMessages(sensitivity_mnar(md_mi(m = 2), delta = 0, type = "mbco"))
  expect_equal(s_pmm@mechanism_used, "post")
  expect_equal(s_pmm@scale, "raw")
  s_norm <- sensitivity_mnar(md_norm(m = 2), delta = 0, type = "mbco")
  expect_equal(s_norm@mechanism_used, "mnar.norm")
  expect_equal(s_norm@scale, "raw")
  s_bin <- suppressWarnings(sensitivity_mnar(md_binary(m = 2), delta = 0, type = "mbco"))
  expect_equal(s_bin@mechanism_used, "mnar.logreg")
  expect_equal(s_bin@scale, "logodds")
  # A multi-target grid can mix routes; one entry per target.
  d <- gen_mnar()
  d$Y[runif(nrow(d)) < 0.2] <- NA
  meth <- mice::make.method(d)
  meth["Y"] <- "norm"
  imp <- mice::mice(d, m = 2, maxit = 2, method = meth, printFlag = FALSE, seed = 7)
  md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M")
  s_mix <- suppressMessages(sensitivity_mnar(md, delta = data.frame(M = 0, Y = 0), type = "mbco"))
  expect_equal(s_mix@mechanism_used, c("post", "mnar.norm"))
})

test_that("print() and tidy() state the mechanism and the delta scale", {
  s_bin <- suppressWarnings(sensitivity_mnar(md_binary(m = 2), delta = c(0, 1), type = "mbco"))
  out <- capture.output(print(s_bin))
  expect_true(any(grepl("mnar.logreg", out, fixed = TRUE)))
  expect_true(any(grepl("log-odds", out, fixed = TRUE)))
  expect_true(any(grepl("probability scale", out, fixed = TRUE)))
  tb <- tidy(s_bin)
  expect_equal(unique(tb$mechanism), "mnar.logreg")
  expect_equal(unique(tb$scale), "logodds")
})

test_that("a supplied scale that contradicts the routed mechanism is an error", {
  md <- md_binary(m = 2)
  expect_error(
    suppressWarnings(sensitivity_mnar(md, delta = 1, scale = "raw")),
    "log-odds"
  )
  expect_no_error(suppressWarnings(
    sensitivity_mnar(md, delta = 0, type = "mbco", scale = "logodds")
  ))
  expect_error(
    suppressMessages(sensitivity_mnar(md_mi(m = 2), delta = 1, scale = "logodds")),
    "raw"
  )
})
