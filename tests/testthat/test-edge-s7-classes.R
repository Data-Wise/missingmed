# Edge cases for the S7 classes: validators, accessors, print/summary/tidy.
# Objects are built directly from their constructors, so each validator branch
# is reached without going through set_md_mediation().

skip_if_not_installed("medfit")
skip_if_not_installed("mice")

# Fixtures ---------------------------------------------------------------------
edge_data <- function() {
  set.seed(4127)
  n <- 120
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.4 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[sample(n, 20)] <- NA
  d$Y[sample(n, 20)] <- NA
  d
}
edge_d <- edge_data()
edge_imp <- mice::mice(edge_d, m = 2, method = "norm", printFlag = FALSE, seed = 4127)
edge_md <- set_md_mediation(edge_imp, Y ~ X + M + C, M ~ X + C,
  treatment = "X", mediator = "M"
)
edge_fit <- run(edge_md)
edge_res <- pool(edge_fit)

# Build an MDMediationData directly, overriding any property.
new_md <- function(...) {
  args <- list(
    data = edge_imp, formula_y = Y ~ X + M + C, formula_m = M ~ X + C,
    treatment = "X", mediator = "M", family_y = stats::gaussian(),
    family_m = stats::gaussian(), n_imputations = 2, original_data = edge_d
  )
  args[names(list(...))] <- list(...)
  do.call(MDMediationData, args)
}
new_fit <- function(...) {
  args <- list(
    per_imputation = edge_fit@per_imputation, fits = edge_fit@fits, m = 2,
    source = edge_md
  )
  args[names(list(...))] <- list(...)
  do.call(MDMediationFit, args)
}
new_res <- function(...) {
  args <- list(
    pooled = edge_res@pooled, tidy_table = edge_res@tidy_table,
    cov_total = edge_res@cov_total, m = 2
  )
  args[names(list(...))] <- list(...)
  do.call(MDMediationResult, args)
}
new_mbco <- function(p = 0.03, nu = 20, ...) {
  args <- list(c(D4 = 4.1, p = p, r4 = 0.5, nu = nu, d_S = 6),
    ariv = "fixed", k = 1, m = 3, stacked_branch = "b", branch_mix = FALSE,
    p_branch_a = 0
  )
  args[names(list(...))] <- list(...)
  do.call(MbcoMIResult, args)
}
# An "mc" rung has the shape of RMediation::ci_mediation_data()'s value.
mc_rung <- function(est, lo, hi) list(CI = c(lo, hi), Estimate = est, SE = 0.1)
new_sens <- function(...) {
  args <- list(
    rungs = list(mc_rung(0.2, 0.05, 0.4), mc_rung(0.1, -0.02, 0.25)),
    grid = data.frame(M = c(0, 0.5)), msp = c(0, 0.3), target = "M",
    type = "mc", level = 0.95, seed = 1, method_target = "norm",
    mechanism_used = "post", scale = "raw"
  )
  args[names(list(...))] <- list(...)
  do.call(MDSensitivityResult, args)
}

# MDMediationData --------------------------------------------------------------
test_that("MDMediationData validator rejects bad estimator and data pairings", {
  expect_s7_class(new_md(), MDMediationData)
  expect_error(new_md(method = "foo"), "@method must be a single string", fixed = TRUE)
  expect_error(new_md(method = NA_character_), "@method must be a single string", fixed = TRUE)
  expect_error(new_md(method = c("mi", "ipw")), "@method must be a single string", fixed = TRUE)
  expect_error(new_md(data = edge_d), "must be a 'mids' object", fixed = TRUE)
  expect_error(new_md(method = "ipw"), "@data must be a data.frame when method = 'ipw'", fixed = TRUE)
  expect_error(new_md(formula_y = "Y ~ X"), "must be formula objects", fixed = TRUE)
  expect_error(new_md(formula_m = NULL), "must be formula objects", fixed = TRUE)
})

test_that("MDMediationData validator rejects bad scalar options", {
  expect_error(new_md(mechanism = "mcar"), "@mechanism must be a single string", fixed = TRUE)
  expect_error(new_md(weight_trim = 0), "@weight_trim must be a single number in (0, 1]", fixed = TRUE)
  expect_error(new_md(weight_trim = 1.5), "@weight_trim must be a single number in (0, 1]", fixed = TRUE)
  expect_error(new_md(weight_trim = c(0.9, 0.95)), "@weight_trim must be", fixed = TRUE)
  expect_error(new_md(se_type = "robust"), "@se_type must be a single string", fixed = TRUE)
  expect_error(new_md(conf_int = c(TRUE, FALSE)), "@conf_int must be a single logical", fixed = TRUE)
  expect_error(new_md(conf_level = 1), "@conf_level must be a single number in (0, 1)", fixed = TRUE)
  expect_error(new_md(conf_level = NA_real_), "@conf_level must be", fixed = TRUE)
  expect_error(new_md(conf_level = c(0.9, 0.95)), "@conf_level must be", fixed = TRUE)
})

test_that("a missing weight_trim is a validator message, not an if() crash", {
  # On v0.5.0 this was "missing value where TRUE/FALSE needed".
  expect_error(new_md(weight_trim = NA_real_), "@weight_trim must be a single number", fixed = TRUE)
})

test_that("treatment and mediator must be distinct, non-missing names", {
  expect_error(new_md(treatment = c("X", "C")), "must each be a single variable name", fixed = TRUE)
  expect_error(new_md(treatment = character(0)), "must each be a single variable name", fixed = TRUE)
  expect_error(new_md(treatment = NA_character_), "must each be a single variable name", fixed = TRUE)
  expect_error(new_md(mediator = ""), "must each be a single variable name", fixed = TRUE)
  # run() fitted this without complaint on v0.5.0.
  expect_error(new_md(mediator = "X"), "must name different variables", fixed = TRUE)
})

test_that("engine must be a single string", {
  expect_error(new_md(engine = c("glm", "regmedint")), "@engine must be a single string", fixed = TRUE)
  expect_error(new_md(engine = character(0)), "@engine must be a single string", fixed = TRUE)
  expect_error(new_md(engine = NA_character_), "@engine must be a single string", fixed = TRUE)
})

test_that("weight_stabilize must be TRUE or FALSE for IPW", {
  # run() read NA via isTRUE() and silently fitted unstabilized weights.
  # set_md_mediation() names the argument before the validator runs.
  expect_error(
    new_md(method = "ipw", data = edge_d, n_imputations = 1, weight_stabilize = NA),
    "@weight_stabilize must be TRUE or FALSE", fixed = TRUE
  )
  expect_error(
    new_md(method = "ipw", data = edge_d, n_imputations = 1, weight_stabilize = c(TRUE, FALSE)),
    "@weight_stabilize must be TRUE or FALSE", fixed = TRUE
  )
  expect_error(
    set_md_mediation(edge_d, Y ~ X + M + C, M ~ X + C,
      treatment = "X", mediator = "M", method = "ipw", weight_stabilize = NA
    ),
    "`weight_stabilize` must be TRUE or FALSE", fixed = TRUE
  )
  # Ignored under MI, so not checked there.
  expect_s7_class(new_md(weight_stabilize = NA), MDMediationData)
})

test_that("n_imputations must match the data when supplied", {
  expect_error(new_md(n_imputations = 5), "must equal the number of imputations in @data (2)", fixed = TRUE)
  expect_error(new_md(n_imputations = NA_real_), "@n_imputations must equal", fixed = TRUE)
  expect_error(new_md(n_imputations = c(2, 2)), "@n_imputations must equal", fixed = TRUE)
  expect_error(
    new_md(method = "ipw", data = edge_d, n_imputations = 2),
    "number of imputations in @data (1)", fixed = TRUE
  )
  # Left empty it is not checked (nothing but print() reads it).
  expect_s7_class(new_md(n_imputations = numeric(0)), MDMediationData)
  expect_s7_class(new_md(method = "ipw", data = edge_d, n_imputations = 1), MDMediationData)
})

test_that("property assignment is validated too", {
  md <- edge_md
  expect_error(md@mediator <- "X", "must name different variables", fixed = TRUE)
  expect_error(md@n_imputations <- 3, "@n_imputations must equal", fixed = TRUE)
})

test_that("print(<MDMediationData>) reports both estimators", {
  expect_output(print(edge_md), "estimator \\(method\\): mi")
  expect_output(print(edge_md), "imputations \\(m\\)\\s+: 2")
  ipw <- new_md(method = "ipw", data = edge_d, n_imputations = 1)
  expect_output(print(ipw), "estimator \\(method\\): ipw")
  expect_output(expect_invisible(print(ipw)))
})

# MDMediationFit ---------------------------------------------------------------
test_that("MDMediationFit validator catches a bad count of imputations", {
  expect_s7_class(new_fit(), MDMediationFit)
  expect_error(new_fit(conf_level = 0), "@conf_level must be", fixed = TRUE)
  # On v0.5.0, NA crashed inside the validator.
  expect_error(new_fit(m = NA_real_), "@m must be a single positive number", fixed = TRUE)
  expect_error(new_fit(m = 0), "@m must be a single positive number", fixed = TRUE)
  expect_error(new_fit(m = c(2, 2)), "@m must be a single positive number", fixed = TRUE)
  expect_error(new_fit(m = 3), "@per_imputation must have length @m", fixed = TRUE)
  expect_error(new_fit(m = 2.5), "@per_imputation must have length @m", fixed = TRUE)
})

test_that("per_imputation must hold medfit fits", {
  # On v0.5.0 these constructed, then print() and pool() failed on `@`.
  expect_error(new_fit(per_imputation = list(1, 2)), "@per_imputation must hold medfit mediation fits", fixed = TRUE)
  expect_error(
    new_fit(per_imputation = list(edge_fit@per_imputation[[1]], NULL)),
    "@per_imputation must hold medfit mediation fits", fixed = TRUE
  )
  fit <- edge_fit
  expect_error(fit@per_imputation <- list(edge_md, edge_md), "must hold medfit mediation fits", fixed = TRUE)
})

test_that("print(<MDMediationFit>) summarizes the per-imputation fits", {
  expect_output(print(edge_fit), "per-imputation fits: 2")
  expect_output(print(edge_fit), "a\\*b: mean =")
  expect_output(expect_invisible(print(edge_fit)))
})

# MDMediationResult ------------------------------------------------------------
test_that("MDMediationResult validator catches bad m and pooled", {
  expect_s7_class(new_res(), MDMediationResult)
  expect_error(new_res(m = NA_real_), "@m must be a single positive number", fixed = TRUE)
  expect_error(new_res(m = 0), "@m must be a single positive number", fixed = TRUE)
  expect_error(new_res(conf_level = 2), "@conf_level must be", fixed = TRUE)
  # On v0.5.0 a NULL pooled constructed, then print/summary/infer failed on `@`.
  expect_error(new_res(pooled = NULL), "@pooled must be a medfit mediation fit", fixed = TRUE)
  expect_error(new_res(pooled = list(a_path = 1, b_path = 1)), "@pooled must be", fixed = TRUE)
})

test_that("print(<MDMediationResult>) survives the default empty tidy_table", {
  r <- new_res(tidy_table = data.frame())
  expect_output(print(r), "no pooled estimates table", fixed = TRUE)
  expect_output(print(r), "indirect effect a*b =", fixed = TRUE)
  expect_s3_class(tidy(r), "tbl_df")
  expect_equal(nrow(tidy(r)), 0L)
})

test_that("print/summary/tidy of a pooled result", {
  expect_output(print(edge_res), "m = 2")
  expect_output(print(edge_res), "infer(type = \"mc\")", fixed = TRUE)
  out <- capture.output(s <- summary(edge_res))
  expect_true(any(grepl("Rubin's rules", out, fixed = TRUE)))
  expect_identical(s, edge_res@tidy_table)
  tb <- tidy(edge_res)
  expect_s3_class(tb, "tbl_df")
  expect_true(all(c("a", "b", "c_prime") %in% tb$term))
})

# Accessors --------------------------------------------------------------------
test_that("accessors return the counts and reject other classes", {
  expect_equal(n_imputations(edge_fit), 2)
  expect_equal(n_imputations(edge_res), 2)
  pil <- per_imputation_list(edge_fit)
  expect_named(pil, c("per_imputation", "m"))
  expect_length(pil$per_imputation, 2)
  expect_error(per_imputation_list(edge_res), "per_imputation_list")
  expect_error(per_imputation_list(edge_md), "per_imputation_list")
  expect_error(per_imputation_list(list()), "per_imputation_list")
  expect_error(n_imputations(edge_d), "n_imputations")
  expect_error(n_imputations(edge_md), "n_imputations")
})

# MbcoMIResult -----------------------------------------------------------------
test_that("MbcoMIResult validator covers each property", {
  expect_s7_class(new_mbco(), MbcoMIResult)
  bad_names <- c(a = 1, b = 2, c = 3, d = 4, e = 5)
  expect_error(
    MbcoMIResult(bad_names, ariv = "fixed", k = 1, m = 3, stacked_branch = "b",
      branch_mix = FALSE, p_branch_a = 0),
    "named D4, p, r4, nu, d_S", fixed = TRUE
  )
  expect_error(new_mbco(ariv = "both"), "@ariv must be", fixed = TRUE)
  expect_error(new_mbco(ariv = NA_character_), "@ariv must be", fixed = TRUE)
  expect_error(new_mbco(k = 0), "@k must be a single positive number", fixed = TRUE)
  expect_error(new_mbco(k = NA_real_), "@k must be a single positive number", fixed = TRUE)
  expect_error(new_mbco(m = 1), "@m must be a single number of imputations, at least 2", fixed = TRUE)
  expect_error(new_mbco(m = NA_real_), "@m must be", fixed = TRUE)
  expect_error(new_mbco(stacked_branch = "c"), "@stacked_branch must be", fixed = TRUE)
  expect_error(new_mbco(stacked_branch = NA_character_), "@stacked_branch must be", fixed = TRUE)
  expect_error(new_mbco(branch_mix = NA), "@branch_mix must be TRUE or FALSE", fixed = TRUE)
  expect_error(new_mbco(p_branch_a = 1.5), "@p_branch_a must be a single number in [0, 1]", fixed = TRUE)
  expect_error(new_mbco(p_branch_a = NA_real_), "@p_branch_a must be", fixed = TRUE)
})

test_that("MbcoMIResult indexes like the old plain vector, but not with $", {
  r <- new_mbco()
  expect_true(is.numeric(r))
  expect_equal(r[["p"]], 0.03)
  expect_equal(r["p"], c(p = 0.03))
  expect_equal(r[2], c(p = 0.03))
  expect_equal(r[c("D4", "nu")], c(D4 = 4.1, nu = 20))
  expect_identical(unname(r["zz"]), NA_real_)
  expect_error(r[["zz"]], "subscript out of bounds")
  expect_error(r$p, "\\$")
  expect_identical(names(S7::S7_data(r)), c("D4", "p", "r4", "nu", "d_S"))
})

test_that("print/tidy of MbcoMIResult with Inf df and a missing p", {
  r <- new_mbco(nu = Inf, p_branch_a = 0.5, branch_mix = TRUE, stacked_branch = "a")
  expect_output(print(r), "F(1, Inf)", fixed = TRUE)
  expect_output(print(r), "a = 0 branch", fixed = TRUE)
  expect_output(print(r), "(mixed)", fixed = TRUE)
  expect_output(expect_invisible(print(r)))
  tb <- tidy(r)
  expect_named(tb, c(
    "term", "statistic", "df1", "df2", "p_value", "r4", "d_S", "ariv",
    "stacked_branch", "branch_mix", "p_branch_a", "m"
  ))
  expect_identical(tb$df2, Inf)
  na_p <- new_mbco(p = NA_real_)
  expect_output(print(na_p), "p = NA", fixed = TRUE)
  expect_true(is.na(tidy(na_p)$p_value))
})

# MDSensitivityResult ----------------------------------------------------------
test_that("MDSensitivityResult validator: shape of rungs, grid and msp", {
  expect_s7_class(new_sens(), MDSensitivityResult)
  # On v0.5.0 an empty result constructed, then print/summary failed in tidy().
  expect_error(
    new_sens(rungs = list(), grid = data.frame(M = numeric()), msp = numeric()),
    "@rungs must hold at least one inference result", fixed = TRUE
  )
  expect_error(new_sens(grid = data.frame(M = 0)), "@grid must have one row per element", fixed = TRUE)
  expect_error(new_sens(msp = 1), "@msp must be empty or have one value per rung", fixed = TRUE)
  expect_error(new_sens(type = "boot"), "@type must be a single string", fixed = TRUE)
  expect_error(new_sens(mechanism_used = "shift"), "@mechanism_used entries must be", fixed = TRUE)
  expect_error(new_sens(scale = "probit"), "@scale entries must be", fixed = TRUE)
})

test_that("rungs must match @type", {
  # On v0.5.0 these constructed, then tidy() failed with a vapply/`$` error.
  expect_error(new_sens(type = "mbco"), "@rungs must all be 'mbco' inference results (with D4 and p); rung(s) 1, 2", fixed = TRUE)
  expect_error(
    new_sens(rungs = list(mc_rung(0.2, 0.05, 0.4), new_mbco())),
    "rung(s) 2 are not", fixed = TRUE
  )
  # A plain named vector (the pre-0.5 mbco value) still qualifies.
  plain <- c(D4 = 4.1, p = 0.2, r4 = 0, nu = Inf, d_S = 4.1)
  s <- new_sens(rungs = list(new_mbco(0.01), plain), type = "mbco")
  expect_equal(tidy(s)$p_value, c(0.01, 0.2))
})

test_that("level must be a single number in (0, 1)", {
  # On v0.5.0 level = 1.5 made every mbco rung "retain" the null.
  expect_error(new_sens(level = 1.5), "@level must be a single number in (0, 1)", fixed = TRUE)
  expect_error(new_sens(level = NA_real_), "@level must be", fixed = TRUE)
  expect_error(new_sens(level = c(0.9, 0.95)), "@level must be", fixed = TRUE)
})

test_that("tidy() fills an empty msp with NA", {
  tb <- tidy(new_sens(msp = numeric()))
  expect_equal(nrow(tb), 2L)
  expect_true(all(is.na(tb$msp)))
})

test_that("a single-rung curve prints and summarizes", {
  s <- new_sens(rungs = list(mc_rung(0.1, -0.02, 0.25)), grid = data.frame(M = 0.5), msp = 0.3)
  expect_output(print(s), "rungs: 1")
  sm <- summary(s)
  expect_equal(sm$tipping$M, 0.5)
  expect_output(print(sm), "Tipping point: the smallest departure")
})

test_that("summary() names NA rungs instead of crashing", {
  # On v0.5.0 any NA rung failed with "missing value where TRUE/FALSE needed".
  na_rung <- mc_rung(NA_real_, NA_real_, NA_real_)
  for (rungs in list(
    list(na_rung, na_rung),
    list(na_rung, mc_rung(0.1, -0.02, 0.25)),
    list(mc_rung(0.2, 0.05, 0.4), na_rung)
  )) {
    s <- new_sens(rungs = rungs)
    expect_output(print(s), "MNAR sensitivity curve")
    sm <- summary(s)
    expect_null(sm$tipping)
    expect_true(length(sm$na_rungs) > 0L)
    out <- capture.output(print(sm))
    expect_true(any(grepl("Tipping point not computed: rung(s)", out, fixed = TRUE)))
    expect_false(any(grepl("No tipping point within", out, fixed = TRUE)))
  }
  mb <- new_sens(rungs = list(new_mbco(NA_real_), new_mbco(0.2)), type = "mbco")
  expect_identical(summary(mb)$na_rungs, 1L)
})

test_that("summary() tipping logic across mc and mbco curves", {
  # MAR rejects, 0.5 retains: tipping at 0.5.
  expect_equal(summary(new_sens())$tipping$M, 0.5)
  # Null already retained at MAR: no tipping point.
  sm <- summary(new_sens(rungs = list(mc_rung(0.1, -0.1, 0.3), mc_rung(0.1, -0.1, 0.3))))
  expect_null(sm$tipping)
  expect_output(print(sm), "No tipping point within the supplied grid")
  # No MAR rung, all retain: the smallest departure is reported.
  sm <- summary(new_sens(
    rungs = list(mc_rung(0.1, -0.1, 0.3), mc_rung(0.1, -0.1, 0.3)),
    grid = data.frame(M = c(0.5, 0.2))
  ))
  expect_equal(sm$tipping$M, 0.2)
  # mbco: retained when p > 1 - level.
  mb <- new_sens(rungs = list(new_mbco(0.01), new_mbco(0.2)), type = "mbco")
  expect_equal(summary(mb)$tipping$M, 0.5)
  expect_null(summary(new_sens(rungs = list(new_mbco(0.01), new_mbco(0.2)), type = "mbco", level = 0.5))$tipping)
  expect_output(print(mb), "inference: mbco")
})

test_that("summary() of a non-numeric grid declines a tipping point", {
  sm <- summary(new_sens(grid = data.frame(M = c("a", "b"))))
  expect_false(sm$ordered)
  expect_null(sm$tipping)
  expect_output(print(sm), "Tipping point not computed: a `ums` grid", fixed = TRUE)
})

test_that("print() truncates long curves and labels the log-odds scale", {
  long <- new_sens(
    rungs = rep(list(mc_rung(0.2, 0.05, 0.4)), 12),
    grid = data.frame(M = seq(0.1, 1.2, by = 0.1)), msp = seq(0.1, 1.2, by = 0.1)
  )
  expect_output(print(long), "... 2 more rung(s)", fixed = TRUE)
  lo <- new_sens(mechanism_used = "mnar.logreg", scale = "logodds")
  expect_output(print(lo), "mnar.logreg (log-odds)", fixed = TRUE)
  expect_output(print(lo), "log-odds scale, while msp is a prevalence")
})

test_that("an NA rung farther from MAR than the tipping point does not block it", {
  grid <- data.frame(M = c(0, 0.5, 1))
  na_rung <- mc_rung(NA_real_, NA_real_, NA_real_)
  # MAR rejects, 0.5 retains, the NA rung is at 1: the tipping point is known.
  s <- new_sens(
    rungs = list(mc_rung(0.2, 0.05, 0.4), mc_rung(0.1, -0.02, 0.25), na_rung),
    grid = grid, msp = c(0, 0.3, 0.6)
  )
  sm <- summary(s)
  expect_equal(sm$tipping$M, 0.5)
  expect_identical(sm$na_rungs, 3L)
  expect_false(sm$undetermined)
  out <- capture.output(print(sm))
  expect_true(any(grepl("Tipping point: the smallest departure", out, fixed = TRUE)))
  expect_true(any(grepl("Rung(s) 3 have a missing (NA) verdict but cannot change", out, fixed = TRUE)))
  # The NA rung at 0.5, inside the first retaining rung at 1: undetermined.
  s2 <- new_sens(
    rungs = list(mc_rung(0.2, 0.05, 0.4), na_rung, mc_rung(0.1, -0.02, 0.25)),
    grid = grid, msp = c(0, 0.3, 0.6)
  )
  sm2 <- summary(s2)
  expect_null(sm2$tipping)
  expect_true(sm2$undetermined)
  expect_output(print(sm2), "Tipping point not computed: rung(s) 2", fixed = TRUE)
  # Null retained at MAR: no tipping point whatever the NA rung would say.
  s3 <- new_sens(
    rungs = list(mc_rung(0.1, -0.02, 0.25), na_rung, mc_rung(0.2, 0.05, 0.4)),
    grid = grid, msp = c(0, 0.3, 0.6)
  )
  sm3 <- summary(s3)
  expect_null(sm3$tipping)
  expect_false(sm3$undetermined)
  expect_output(print(sm3), "No tipping point within the supplied grid")
  # A tie in distance with the found tipping point is undetermined too.
  s4 <- new_sens(
    rungs = list(mc_rung(0.2, 0.05, 0.4), mc_rung(0.1, -0.02, 0.25), na_rung),
    grid = data.frame(M = c(0, 0.5, -0.5)), msp = c(0, 0.3, -0.3)
  )
  expect_true(summary(s4)$undetermined)
})

test_that("print() of an mbco curve names its ariv", {
  s <- new_sens(rungs = list(new_mbco(0.01), new_mbco(0.2, ariv = "own")), type = "mbco")
  expect_output(print(s), "inference: mbco (ariv = \"fixed\")", fixed = TRUE)
  expect_false(any(grepl("ariv", capture.output(print(new_sens())))))
})
