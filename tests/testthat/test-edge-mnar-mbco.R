# Edge cases and known answers for sensitivity_mnar() and mbco_d4().
#
# Each guard here was added only after the bad input was run on the unguarded
# code and found to give a silent wrong answer or an obscure/late error; inputs
# that already failed clearly are pinned, and plausible valid uses are pinned as
# working so a later guard cannot refuse them.

skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
skip_if_not_installed("mice")

# ── helpers ─────────────────────────────────────────────────────────────────

em_gen <- function(n = 120, seed = 7) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < plogis(-1 + 0.5 * C)] <- NA
  d
}
em_spec <- function(imp) {
  set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M")
}
# Materialize the data before mice() so its seed is not overridden by
# em_gen()'s own set.seed() (see test-sensitivity-mnar.R).
em_md <- function(m = 2, seed = 11) {
  d <- em_gen()
  em_spec(mice::mice(d, m = m, maxit = 2, printFlag = FALSE, seed = seed))
}
em_sens <- function(...) suppressMessages(sensitivity_mnar(...))
# Fails the test if a guard lets the input through to re-imputation.
em_no_reimpute <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    .mnar_reimpute = function(...) stop("re-imputation reached"),
    .env = env
  )
}

em_d <- function(n = 120, seed = 1) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rnorm(n)
  M <- 0.4 * X + 0.3 * C + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + 0.3 * C + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C = C)
}
em_il <- function(K = 3, n = 120) lapply(seq_len(K), function(s) em_d(n, seed = s))
em_d4 <- function(il, ..., formula_y = Y ~ X + M + C, formula_m = M ~ X + C) {
  mbco_d4(il, formula_y, formula_m, treatment = "X", mediator = "M", ...)
}

# ── sensitivity_mnar(): delta = 0 known answer ──────────────────────────────

test_that("delta = 0 reproduces the MAR MBCO result in every component", {
  md <- em_md()
  sens <- em_sens(md, delta = 0, type = "mbco")
  base <- infer(run(md), type = "mbco")
  r <- sens@rungs[[1]]
  expect_equal(S7::S7_data(r), S7::S7_data(base))
  expect_identical(r@stacked_branch, base@stacked_branch)
  expect_identical(r@branch_mix, base@branch_mix)
  expect_equal(r@k, base@k)
  expect_equal(r@m, base@m)
})

test_that("delta = 0 reproduces the MAR Monte-Carlo interval when RNG streams align", {
  # The MC interval is random, so the MAR side must start its draws from the
  # same RNG state as the rung. Both sides call mice() with the same seed
  # immediately before run() -> pool() -> infer(). This relies on nothing
  # between the re-imputation and infer() consuming random numbers (the
  # delta = 0 post shift, the finiteness check and the msp summary do not).
  d <- em_gen()
  imp <- mice::mice(d, m = 2, maxit = 2, printFlag = FALSE, seed = 11)
  sens <- em_sens(em_spec(imp), delta = 0, n.mc = 2e3)
  imp2 <- mice::mice(d, m = 2, maxit = 2, printFlag = FALSE, seed = 11)
  base <- infer(pool(run(em_spec(imp2))), type = "mc", n.mc = 2e3)
  expect_identical(sens@rungs[[1]], base)
})

# ── sensitivity_mnar(): delta shapes ────────────────────────────────────────

test_that("empty and non-numeric vector deltas are refused (existing guard)", {
  md <- em_md()
  em_no_reimpute()
  for (bad in list(numeric(0), NULL, "1", TRUE, factor(1), list(0, 1))) {
    expect_error(sensitivity_mnar(md, delta = bad), "non-empty numeric vector")
  }
  expect_error(sensitivity_mnar(md, delta = NaN), "`delta` must be finite")
  expect_error(sensitivity_mnar(md, delta = -Inf), "`delta` must be finite")
  expect_error(sensitivity_mnar(md, delta = data.frame(M = numeric(0))),
    "at least one row")
  expect_error(sensitivity_mnar(md, delta = data.frame()), "at least one row")
})

test_that("a multi-column matrix delta is refused; a one-column matrix is a vector", {
  md <- em_md()
  # Unguarded, a 1 x 2 matrix became an unnamed second target ("Target 'NA'").
  local({
    em_no_reimpute()
    expect_error(sensitivity_mnar(md, delta = matrix(c(0, 1), ncol = 2)),
      "must be a vector.*data frame")
  })
  as_mat <- em_sens(md, delta = matrix(c(0, 1), ncol = 1), type = "mbco")
  as_vec <- em_sens(md, delta = c(0, 1), type = "mbco")
  expect_equal(as_mat@grid, as_vec@grid)
  expect_equal(as_mat@rungs, as_vec@rungs)
})

test_that("delta data frame columns need unique, non-empty names", {
  md <- em_md()
  em_no_reimpute()
  # Unguarded, a duplicated name shifted by the FIRST column only: the M = 1
  # rung silently reported the delta = 0 result, and tidy() then crashed.
  dup <- stats::setNames(data.frame(0, 1), c("M", "M"))
  expect_error(sensitivity_mnar(md, delta = dup), "unique, non-empty names")
  # Unguarded, these said "column 'NA' must be numeric" for a numeric column.
  expect_error(sensitivity_mnar(md, delta = stats::setNames(data.frame(1), NA)),
    "unique, non-empty names")
  expect_error(sensitivity_mnar(md, delta = stats::setNames(data.frame(1), "")),
    "unique, non-empty names")
})

test_that("integer, named and duplicated deltas are valid", {
  md <- em_md()
  int <- em_sens(md, delta = 0L, type = "mbco")
  dbl <- em_sens(md, delta = 0, type = "mbco")
  expect_equal(int@rungs, dbl@rungs)
  named <- em_sens(md, delta = c(lo = 0, hi = 1), type = "mbco")
  expect_equal(named@grid$M, c(0, 1))
  # A repeated rung is redundant but well defined: the same draws twice.
  twice <- em_sens(md, delta = c(0, 0), type = "mbco")
  expect_equal(S7::S7_data(twice@rungs[[1]]), S7::S7_data(twice@rungs[[2]]))
  expect_equal(twice@msp[1], twice@msp[2])
})

# ── sensitivity_mnar(): target ──────────────────────────────────────────────

test_that("bad targets are refused before re-imputation (existing guards)", {
  md <- em_md()
  em_no_reimpute()
  expect_error(sensitivity_mnar(md, delta = 0, target = character(0)),
    "exactly one variable")
  expect_error(sensitivity_mnar(md, delta = 0, target = c("M", "C")),
    "exactly one variable")
  expect_error(sensitivity_mnar(md, delta = 0, target = 1), "'1' is not a column")
  expect_error(sensitivity_mnar(md, delta = 0, target = NA_character_),
    "not a column")
  expect_error(sensitivity_mnar(md, delta = 0, target = "X"), "no missing values")
})

# ── sensitivity_mnar(): seed ────────────────────────────────────────────────

test_that("an invalid seed is refused before any re-imputation", {
  md <- em_md()
  em_no_reimpute()
  # Unguarded: NA_integer_ silently left every rung unseeded (mice skips
  # set.seed() for NA); NA and TRUE failed in the result validator after all
  # rungs ran; c(1, 2) gave "the condition has length > 1". "abc" and Inf
  # already failed in mice, now earlier and with this message.
  # 3e9 failed inside mice(); with `ums` the probe blamed the ums string.
  for (bad in list(NA_integer_, NA, TRUE, c(1, 2), "abc", Inf, NA_real_, 3e9)) {
    expect_error(sensitivity_mnar(md, delta = 0, seed = bad),
      "`seed` must be a single finite number in the integer range")
  }
})

test_that("an invalid level is refused before any re-imputation", {
  md <- em_md()
  em_no_reimpute()
  # Unguarded, type = "mbco" never used `level`: 1.5 and c(0.9, 0.95) were
  # stored silently, NA and "0.9" failed only after every rung ran; level = 0
  # gave a degenerate Monte-Carlo interval without complaint.
  for (bad in list(1.5, 0, 1, NA, NA_real_, c(0.9, 0.95), "0.9")) {
    for (type in c("mbco", "mc")) {
      expect_error(sensitivity_mnar(md, delta = 0, type = type, level = bad),
        "`level` must be a single number strictly between 0 and 1")
    }
  }
})

test_that("an explicit seed pins the curve and is recorded", {
  md <- em_md()
  a <- em_sens(md, delta = c(0, 1), seed = 5, type = "mbco")
  b <- em_sens(md, delta = c(0, 1), seed = 5, type = "mbco")
  expect_equal(a@rungs, b@rungs)
  expect_equal(a@msp, b@msp)
  expect_equal(a@seed, 5)
  expect_identical(a@seed_source, "argument")
  # A fractional seed is accepted; set.seed() truncates it, so it reproduces
  # the integer part while @seed records the value as given.
  frac <- em_sens(md, delta = 1, seed = 5.5, type = "mbco")
  expect_equal(frac@rungs[[1]], a@rungs[[2]])
  expect_equal(frac@seed, 5.5)
})

# ── sensitivity_mnar(): number of imputations ───────────────────────────────

test_that("type = 'mbco' with one imputation fails with the D4 message", {
  md1 <- em_md(m = 1)
  expect_error(em_sens(md1, delta = c(0, 1), type = "mbco"),
    "at least 2 imputations")
  # The Monte-Carlo route has no such floor: one imputation is a single fit.
  mc <- em_sens(md1, delta = c(0, 1), n.mc = 1e3)
  expect_length(mc@rungs, 2L)
})

# ── mbco_d4(): arguments ────────────────────────────────────────────────────

test_that("invalid ariv and an empty implist fail clearly (pinned)", {
  il <- em_il(2)
  expect_error(em_d4(il, ariv = "bogus"), "should be one of")
  expect_error(em_d4(il, ariv = NA), "must be NULL or a character vector")
  expect_error(em_d4(il, ariv = c("own", "fixed")), "must be of length 1")
  expect_error(em_d4(list()), "supplied object has 0")
})

test_that("m = 2 is the working minimum under both ariv values", {
  il <- em_il(2)
  for (ariv in c("fixed", "own")) {
    r <- em_d4(il, ariv = ariv)
    expect_equal(r@m, 2)
    expect_true(all(is.finite(S7::S7_data(r)[c("D4", "p", "r4", "d_S")])))
    expect_true(r[["p"]] >= 0 && r[["p"]] <= 1)
  }
})

test_that("identical imputations give r4 = 0 and the complete-data statistic", {
  # Known answer: K copies of one dataset stack to K times its log-likelihoods,
  # so d_S equals the complete-data T, dbar - d_S = 0, r4 = 0, nu = Inf and
  # D4 = T / k.
  d <- em_d()
  r <- em_d4(list(d, d, d))
  Tk <- missingmed:::.mm_mbco_T(d, Y ~ X + M + C, M ~ X + C, stats::gaussian(),
    stats::gaussian(), "X", "M")
  expect_equal(r[["r4"]], 0)
  expect_equal(r[["nu"]], Inf)
  expect_equal(r[["d_S"]], Tk[["T"]], tolerance = 1e-8)
  expect_equal(r[["D4"]], Tk[["T"]] / Tk[["k"]], tolerance = 1e-8)
})

# ── mbco_d4(): implist shape ────────────────────────────────────────────────

test_that("data frames with different columns are refused, naming the imputation", {
  il <- em_il()
  miss <- il
  miss[[2]]$C <- NULL # unguarded: "invalid type (closure) for variable 'C'"
  expect_error(em_d4(miss), "same columns; imputation 2 .*: C")
  extra <- il
  extra[[3]]$Z <- 1 # unguarded: rbind()'s "numbers of columns ... do not match"
  expect_error(em_d4(extra), "imputation 3 .*: Z")
})

test_that("column order does not matter", {
  il <- em_il()
  re <- il
  re[[2]] <- re[[2]][, c("Y", "C", "M", "X")]
  expect_equal(S7::S7_data(em_d4(re)), S7::S7_data(em_d4(il)))
})

test_that("unequal or zero row counts are refused", {
  il <- em_il()
  short <- il
  short[[2]] <- short[[2]][1:60, ] # unguarded: a silent, finite D4
  expect_error(em_d4(short), "same number of rows.*has 120.*has 60")
  empty <- lapply(il, function(d) d[0, ]) # unguarded: "object 'fit' not found"
  expect_error(em_d4(empty), "have no rows")
})

test_that("a model variable whose type changes across imputations is refused", {
  il <- em_il()
  chr <- il
  chr[[2]]$C <- as.character(chr[[2]]$C) # unguarded: a misleading k error
  expect_error(em_d4(chr), "'C' have a different type in imputation 2")
  fac <- lapply(il, function(d) {
    d$F <- factor(rep(c("a", "b"), length.out = nrow(d)))
    d
  })
  fac[[3]]$F <- as.integer(fac[[3]]$F) # unguarded: a silent, finite D4
  expect_error(em_d4(fac, formula_y = Y ~ X + M + F),
    "'F' have a different type in imputation 3")
  # Integer versus double is the same type, and unused columns are not checked.
  ok <- il
  ok[[2]]$X <- as.integer(round(ok[[2]]$X * 10))
  ok <- lapply(ok, function(d) {
    d$G <- "g"
    d
  })
  ok[[2]]$G <- 1
  expect_true(all(is.finite(S7::S7_data(em_d4(ok))[c("D4", "p", "d_S")])))
})

test_that("NA left in a model variable is refused; NA elsewhere is ignored", {
  il <- em_il()
  na_x <- il
  na_x[[2]]$X[1:5] <- NA # unguarded: silently fit on fewer rows
  expect_error(em_d4(na_x), "Imputation 2 .*'X'.*MBCO needs completed")
  na_z <- lapply(il, function(d) {
    d$Z <- 1
    d
  })
  na_z[[2]]$Z[1:5] <- NA
  expect_equal(S7::S7_data(em_d4(na_z)), S7::S7_data(em_d4(il)))
})

test_that("infer(type = 'mbco') refuses a mids that left a model variable unimputed", {
  # A covariate with method "" keeps its NA in mice::complete(). Unguarded,
  # infer(type = "mbco") silently fit each model on its own complete cases.
  d <- em_gen()
  d$C[c(3, 9, 27, 81)] <- NA
  meth <- mice::make.method(d)
  meth["C"] <- ""
  imp <- mice::mice(d, m = 2, maxit = 2, method = meth, printFlag = FALSE,
    seed = 3)
  fit <- run(em_spec(imp))
  expect_error(infer(fit, type = "mbco"), "Imputation 1 .*'C'.*MBCO needs completed")
})

test_that("a treatment or mediator that is not a column is refused", {
  il <- lapply(em_il(), function(d) {
    names(d)[names(d) == "X"] <- "X2"
    d
  })
  # unguarded: "object 'X' not found" from model.frame()
  expect_error(em_d4(il), "columns of every data frame.*missing: 'X'")
})

test_that("a fit that fails in one imputation names that imputation", {
  il <- lapply(em_il(), function(d) {
    d$F <- factor(rep(c("a", "b"), length.out = nrow(d)))
    d
  })
  il[[2]]$F <- factor(rep("a", nrow(il[[2]])))
  expect_error(em_d4(il, formula_y = Y ~ X + M + F),
    "failed in imputation 2: contrasts can be applied only")
})

test_that("tibbles and a family given as a string are valid input", {
  il <- em_il()
  ref <- S7::S7_data(em_d4(il))
  expect_equal(S7::S7_data(em_d4(lapply(il, tibble::as_tibble))), ref)
  expect_equal(
    S7::S7_data(mbco_d4(il, Y ~ X + M + C, M ~ X + C, family_y = "gaussian",
      treatment = "X", mediator = "M")),
    ref
  )
})

test_that("moderated and transformed models still pass the shape checks", {
  il <- lapply(em_il(), function(d) {
    d$F <- factor(rep(c("a", "b"), length.out = nrow(d)))
    d
  })
  r <- em_d4(il, formula_y = Y ~ X + M * F)
  expect_equal(r@k, 2)
  expect_true(all(is.finite(S7::S7_data(r)[c("D4", "p", "r4", "d_S")])))
  pos <- lapply(il, function(d) {
    d$M <- exp(d$M)
    d
  })
  r2 <- em_d4(pos, formula_y = Y ~ X + M, formula_m = log(M) ~ X)
  expect_true(all(is.finite(S7::S7_data(r2)[c("D4", "p", "r4", "d_S")])))
})
