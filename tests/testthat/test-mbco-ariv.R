# infer(type = "mbco", ariv = ) and mbco_d4() (issue #19).
#
# The fixture holds three synthetic mice implists whose imputations disagree on
# the winning MBCO branch, medsim 0.5.1's D4/p/r4/nu for both ARIV variants, and
# missingmed's pre-#19 infer(type = "mbco") vector. Regenerate it with
# data-raw/make-mbco-d4-fixture.R.

skip_if_not_installed("medfit")
skip_if_not_installed("mice")

fx <- readRDS(test_path("fixtures", "mbco-d4-medsim-0.5.1.rds"))

# Element-wise relative tolerance, with Inf == Inf: nu is Inf when r4 clamps to
# 0. expect_equal()'s tolerance is a mean relative difference over the whole
# vector, which would let a small p hide behind a large nu.
expect_rel_equal <- function(object, expected, tol = 1e-10) {
  object <- unname(object)
  expected <- unname(expected)
  expect_identical(is.infinite(object), is.infinite(expected))
  fin <- is.finite(expected)
  rel <- abs(object[fin] - expected[fin]) / pmax(abs(expected[fin]), .Machine$double.xmin)
  expect_lt(max(rel), tol)
}

d4_case <- function(case, ariv) {
  mbco_d4(case$implist, case$formula_y, case$formula_m,
    family_y = stats::gaussian(), family_m = stats::gaussian(),
    treatment = "X", mediator = "M", ariv = ariv
  )
}

fit_case <- function(case) {
  run(set_md_mediation(case$mids, case$formula_y, case$formula_m,
    treatment = "X", mediator = "M"
  ))
}

# Hand-built implists: mbco_d4() takes data frames, so these need no mice and
# stay fixed if mice's RNG use ever changes.
gen_d <- function(n, a, b, seed, xm = 0) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rnorm(n)
  M <- a * X + 0.3 * C + rnorm(n)
  Y <- b * M + 0.2 * X + xm * X * M + 0.3 * C + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C = C)
}

# ── Parity with medsim 0.5.1 ────────────────────────────────────────────────

test_that("mbco_d4() matches medsim 0.5.1 under both ariv values", {
  for (case in fx$cases) {
    for (ariv in c("fixed", "own")) {
      r <- d4_case(case, ariv)
      expect_rel_equal(r[c("D4", "p", "r4", "nu")], case$expected[[ariv]])
      expect_identical(r@ariv, ariv)
      expect_identical(r@stacked_branch, case$stacked_branch)
      expect_identical(r@branch_mix, case$branch_mix)
      expect_equal(r@p_branch_a, case$p_branch_a)
      expect_equal(r@k, 1)
      expect_equal(r@m, 5)
    }
  }
})

test_that("the fixture exercises both stacked branches and nu = Inf", {
  expect_setequal(vapply(fx$cases, `[[`, "", "stacked_branch"), c("a", "b"))
  nu_own <- vapply(fx$cases, function(z) z$expected$own[["nu"]], numeric(1))
  expect_true(any(is.infinite(nu_own)))
  expect_true(any(is.finite(nu_own)))
})

# ── ariv = "own" reproduces the pre-#19 output ──────────────────────────────

test_that("ariv = 'own' is bit-identical to the old infer(type = 'mbco')", {
  for (case in fx$cases) {
    r <- infer(fit_case(case), type = "mbco", ariv = "own")
    old <- case$legacy_own
    expect_identical(S7::S7_data(r), old)
    expect_identical(r["p"], old["p"])
    expect_identical(r[["p"]], old[["p"]])
    expect_identical(r[c("D4", "nu")], old[c("D4", "nu")])
    # Documented behavior changes: the object is not the bare vector, and `$`
    # errors (the old vector had no `$` either).
    expect_false(identical(r, old))
    expect_error(r$p)
  }
})

test_that("ariv defaults to 'fixed' in infer() and mbco_d4()", {
  case <- fx$cases$seed9
  fit <- fit_case(case)
  r_def <- infer(fit, type = "mbco")
  r_fix <- infer(fit, type = "mbco", ariv = "fixed")
  expect_identical(r_def@ariv, "fixed")
  expect_identical(S7::S7_data(r_def), S7::S7_data(r_fix))
  expect_identical(
    S7::S7_data(d4_case(case, "fixed")),
    S7::S7_data(mbco_d4(case$implist, case$formula_y, case$formula_m,
      treatment = "X", mediator = "M"
    ))
  )
  expect_error(infer(fit, type = "mbco", ariv = "stacked"), "should be one of")
})

test_that("infer() and mbco_d4() agree on the same imputations", {
  case <- fx$cases$seed28
  for (ariv in c("fixed", "own")) {
    expect_identical(
      S7::S7_data(infer(fit_case(case), type = "mbco", ariv = ariv)),
      S7::S7_data(d4_case(case, ariv))
    )
  }
})

test_that("with no branch mixing, 'fixed' and 'own' coincide", {
  implist <- lapply(1:4, function(s) gen_d(300, a = 0.5, b = 0, seed = 100 + s))
  own <- mbco_d4(implist, Y ~ X + M + C, M ~ X + C, treatment = "X",
    mediator = "M", ariv = "own")
  fix <- mbco_d4(implist, Y ~ X + M + C, M ~ X + C, treatment = "X",
    mediator = "M", ariv = "fixed")
  expect_false(fix@branch_mix)
  expect_identical(fix@stacked_branch, "b")
  expect_equal(S7::S7_data(fix), S7::S7_data(own), tolerance = 1e-12)
})

# ── The result class ────────────────────────────────────────────────────────

test_that("the result is an MbcoMIResult with parent class_double", {
  r <- d4_case(fx$cases$seed26, "fixed")
  expect_true(S7::S7_inherits(r, MbcoMIResult))
  expect_true(is.numeric(r))
  expect_true(is.double(S7::S7_data(r)))
  expect_named(r, c("D4", "p", "r4", "nu", "d_S"))
  expect_length(S7::S7_data(r), 5L)
  expect_type(r[["p"]], "double")
  expect_null(attributes(r[["p"]]))
  expect_false(S7::S7_inherits(r["p"]))
  expect_error(r[["p_value"]], "subscript out of bounds")
})

test_that("MbcoMIResult validates its properties", {
  v <- c(D4 = 1, p = 0.3, r4 = 0, nu = Inf, d_S = 1)
  ok <- function(...) {
    args <- utils::modifyList(list(
      .data = v, ariv = "fixed", k = 1, m = 5, stacked_branch = "a",
      branch_mix = FALSE, p_branch_a = 1
    ), list(...))
    do.call(MbcoMIResult, args)
  }
  expect_no_error(ok())
  expect_error(ok(ariv = "both"), "@ariv")
  expect_error(ok(stacked_branch = "c"), "@stacked_branch")
  expect_error(ok(p_branch_a = 2), "@p_branch_a")
  expect_error(ok(.data = c(D4 = 1, p = 0.3)), "D4, p, r4, nu, d_S")
})

test_that("print() and tidy() report the test and the branch diagnostics", {
  r <- d4_case(fx$cases$seed26, "fixed")
  out <- capture.output(print(r))
  expect_match(out[1], "MbcoMIResult")
  expect_true(any(grepl("F(1,", out, fixed = TRUE)))
  expect_true(any(grepl("ariv = \"fixed\"", out, fixed = TRUE)))
  expect_true(any(grepl("b = 0", out, fixed = TRUE)))
  expect_true(any(grepl("mixed", out)))
  capture.output(expect_invisible(print(r)))

  tb <- tidy(r)
  expect_s3_class(tb, "tbl_df")
  expect_equal(nrow(tb), 1L)
  expect_named(tb, c("term", "statistic", "df1", "df2", "p_value", "r4", "d_S",
    "ariv", "stacked_branch", "branch_mix", "p_branch_a", "m"))
  expect_identical(tb$p_value, r[["p"]])
  expect_identical(tb$df2, r[["nu"]])
  expect_identical(tb$df1, r@k)
})

# ── Different k across branches (X:M interaction) ───────────────────────────

xm_implist <- function() {
  # Y ~ X * M + C: dropping the b-path removes M and X:M (k = 2); dropping the
  # a-path from M ~ X + C removes X (k = 1). Imputations 1-3 have a weak a-path
  # (a = 0 wins), 4-5 a weak b-path (b = 0 wins).
  c(
    lapply(1:3, function(s) gen_d(300, a = 0.05, b = 0.5, seed = 10 + s, xm = 0.3)),
    lapply(4:5, function(s) gen_d(300, a = 0.6, b = 0.02, seed = 10 + s))
  )
}

test_that("X:M: 'own' refuses mixed k, 'fixed' uses the stacked fit's k", {
  il <- xm_implist()
  args <- list(il, Y ~ X * M + C, M ~ X + C, treatment = "X", mediator = "M")
  expect_error(do.call(mbco_d4, c(args, ariv = "own")),
    "different number of parameters")
  r <- do.call(mbco_d4, c(args, ariv = "fixed"))
  expect_true(r@branch_mix)
  expect_equal(r@p_branch_a, 0.6)
  stacked <- do.call(rbind, il)
  k_stacked <- if (r@stacked_branch == "a") {
    missingmed:::.mm_drop_df(M ~ X + C, "X", stacked)
  } else {
    missingmed:::.mm_drop_df(Y ~ X * M + C, "M", stacked)
  }
  expect_equal(r@k, k_stacked)
  expect_true(all(is.finite(S7::S7_data(r)[c("D4", "p", "r4", "d_S")])))
  expect_true(any(grepl(paste0("F(", r@k, ","), capture.output(print(r)),
    fixed = TRUE)))
})

# ── Rank guard ──────────────────────────────────────────────────────────────

test_that("'fixed' errors when an imputation's design rank differs from the stacked fit's", {
  il <- lapply(1:3, function(s) {
    d <- gen_d(300, a = 0.4, b = 0.3, seed = 30 + s)
    d$F <- factor(rep(c("u", "v", "w"), length.out = 300))
    d
  })
  # Level "w" is absent from imputation 2 but kept as a level, so the design
  # matrix keeps its column (ncol is unchanged) and loses rank.
  il[[2]]$F[il[[2]]$F == "w"] <- "v"
  expect_identical(levels(il[[2]]$F), c("u", "v", "w"))
  args <- list(il, Y ~ X + M + C + F, M ~ X + C + F, treatment = "X",
    mediator = "M")
  expect_error(do.call(mbco_d4, c(args, ariv = "fixed")), "rank")
  expect_error(do.call(mbco_d4, c(args, ariv = "fixed")), "imputation 2")
})

# ── K = 1 ───────────────────────────────────────────────────────────────────

test_that("K = 1 errors and points to complete-data MBCO", {
  d <- gen_d(300, a = 0.4, b = 0.3, seed = 1)
  for (ariv in c("fixed", "own")) {
    expect_error(
      mbco_d4(list(d), Y ~ X + M + C, M ~ X + C, treatment = "X",
        mediator = "M", ariv = ariv),
      "at least 2 imputations"
    )
    expect_error(
      mbco_d4(list(d), Y ~ X + M + C, M ~ X + C, treatment = "X",
        mediator = "M", ariv = ariv),
      "complete-data MBCO"
    )
  }
})

# ── mbco_d4() input checks ──────────────────────────────────────────────────

test_that("mbco_d4() validates its inputs", {
  il <- lapply(1:2, function(s) gen_d(100, a = 0.4, b = 0.3, seed = s))
  f_y <- Y ~ X + M + C
  f_m <- M ~ X + C
  expect_error(mbco_d4(il[[1]], f_y, f_m, treatment = "X", mediator = "M"),
    "list of data frames")
  expect_error(mbco_d4(list(il[[1]], 1), f_y, f_m, treatment = "X", mediator = "M"),
    "list of data frames")
  expect_error(mbco_d4(il, "Y ~ X", f_m, treatment = "X", mediator = "M"),
    "formula_y")
  expect_error(mbco_d4(il, f_y, f_m, treatment = c("X", "C"), mediator = "M"),
    "treatment")
  expect_error(mbco_d4(il, f_y, f_m, treatment = "X", mediator = "Z"),
    "mediator")
})
