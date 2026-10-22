# T5: stored observations and injected summaries only; no data generators.
skip_if_not_installed("medfit", "0.10.0")
t5_data <- setNames(iris[1:4], c("X", "M", "Y", "C"))
t5_model <- "M ~ X + C; Y ~ M + X + C"
t5_direct <- function(imps = list(t5_data, t5_data), model = t5_model, ...) {
  mbco_d4(imps, model = model, treatment = "X", mediator = "M", outcome = "Y", ...)
}
t5_fit <- function() {
  long <- do.call(rbind, lapply(0:2, function(i) {
    data.frame(.imp = i, .id = seq_len(nrow(t5_data)), t5_data)
  }))
  imp <- withr::with_seed(1, mice::as.mids(long))
  run(set_md_mediation(imp, model = t5_model, treatment = "X", mediator = "M",
    outcome = "Y", engine = "lavaan"))
}

test_that("independent K=20 answers distinguish Chan-Meng from historical Li df", {
  # Exact rational inputs give gap=19/21, r4=1, D4=1 and Chan-Meng nu=76.
  # Expected values never call the helper under test. Li gives 20884/361.
  got <- missingmed:::.mm_d4_from_stats(rep(61 / 21, 20), 2, k = 1)
  expected <- c(D4 = 1, p = stats::pf(1, 1, 76, lower.tail = FALSE),
    r4 = 1, nu = 76, d_S = 2)
  for (nm in names(expected)) expect_equal(got[[nm]], expected[[nm]], tolerance = 1e-12)
  li <- 20884 / 361
  expect_gt(abs(got[["nu"]] - li), 18)
  expect_gt(abs(got[["p"]] - stats::pf(1, 1, li, lower.tail = FALSE)), 0.0009)
  # Existing evidence: NOTE-d4-denominator-vs-mitml-2026-10-09.md, K20/r4=1
  # row. Derive Li's exact value from its equation rather than copying a row;
  # docs/ is excluded from built packages, so there is no runtime docs read.
  expect_equal(li, 4 + (19 - 4) * (1 + (1 - 2 / 19))^2)
})

test_that("zero ARIV and both sides of the rounding-gap threshold are pinned", {
  for (gap in c(-1, 0, 0.5e-10)) {
    got <- missingmed:::.mm_d4_from_stats(rep(1 + gap, 20), 1)
    expect_equal(got[["r4"]], 0)
    expect_identical(got[["nu"]], Inf)
  }
  got <- missingmed:::.mm_d4_from_stats(rep(1 + 2e-10, 20), 1)
  expect_gt(got[["r4"]], 0)
  expect_true(is.finite(got[["nu"]]))
})

test_that("public LR gates cover both branches in every dataset and ARIV mode", {
  fit <- t5_fit()
  index <- 0L
  target <- 0L
  branch <- 1L
  bad <- -1
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    index <<- index + 1L
    list(fit = index, n_obs = nrow(d), improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) {
    lr <- c(1, 9)
    if (fit == target) lr[branch] <- bad
    list(tests = data.frame(constraint = paste(c(a, b), "== 0"),
      f = c(1, 2), diff_ll = lr, converged = TRUE))
  })
  for (mode in c("own", "fixed")) {
    for (target in 1:3) for (branch in 1:2) for (bad in c(-1, Inf, NA_real_)) {
      where <- if (target == 3L) "stacked data" else paste("imputation", target)
      label <- c("mm_a", "mm_b")[branch]
      for (invoke in list(function() t5_direct(ariv = mode),
        function() infer(fit, type = "mbco", ariv = mode))) {
        index <- 0L
        expect_error(invoke(), paste0(where, ".*(negative LR|Non-finite LR).*", label))
      }
    }
  }
})

test_that("public incomplete refits never become a successful survivor", {
  fit <- t5_fit()
  state <- "ok"
  index <- 0L
  target <- 1L
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    index <<- index + 1L
    list(fit = index, n_obs = nrow(d), improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) {
    tab <- data.frame(constraint = paste(c(a, b), "== 0"),
      f = c(1, 2), diff_ll = c(1, 9), converged = TRUE)
    if (fit == target) {
      tab <- switch(state, only_a = tab[1, ], only_b = tab[2, ],
        duplicate = tab[c(1, 1), ], none = tab[FALSE, ],
        failed_a = transform(tab, converged = c(FALSE, TRUE)),
        failed_b = transform(tab, converged = c(TRUE, FALSE)),
        all_failed = transform(tab, converged = FALSE),
        nonfinite_f = transform(tab, f = c(1, Inf)), tab)
      if (state %in% c("optimizer a = 0", "post-fit covariance b = 0")) stop(state)
    }
    list(tests = tab)
  })
  for (mode in c("own", "fixed")) for (target in 1:3) {
    for (state in c("only_a", "only_b", "duplicate", "none", "failed_a", "failed_b",
      "all_failed", "nonfinite_f", "optimizer a = 0", "post-fit covariance b = 0")) {
      where <- if (target == 3L) "stacked data" else paste("imputation", target)
      for (invoke in list(function() t5_direct(ariv = mode),
        function() infer(fit, type = "mbco", ariv = mode))) {
        index <- 0L
        detail <- if (grepl(" = 0", state, fixed = TRUE)) state else "incomplete"
        expect_error(invoke(), paste0(where, ".*", detail))
      }
    }
  }
  state <- "ok"
  index <- 0L
  r <- t5_direct()
  expect_equal(r[["d_S"]], 0.5)
  expect_identical(r@stacked_branch, "a")
  expect_identical(r@p_branch_a, 1)
})

test_that("encoding, own/fixed selection, ties and labeled diagnostics are independent", {
  imps <- list(data.frame(id = 1), data.frame(id = 2))
  # Raw branch LRs: (1,9), (9,3), stack (8,12). Own mean=2; fixed mean=5.
  rows <- rbind(c(1, 9), c(9, 3), c(8, 12))
  provider <- function(d) {
    i <- if (nrow(d) == 2L) 3L else d$id
    c(full = 0, a = -rows[i, 1] / 2, b = -rows[i, 2] / 2, k_a = 1, k_b = 1)
  }
  for (mode in c("own", "fixed")) {
    r <- missingmed:::.mm_d4_pool(imps, provider, mode)
    riv <- if (mode == "own") 0 else 3
    expect_equal(r[["d_S"]], 4)
    expect_equal(r[["r4"]], riv)
    expect_equal(r[["D4"]], 4 / (1 + riv))
    expect_identical(r@stacked_branch, "a")
    expect_true(r@branch_mix)
    expect_equal(r@p_branch_a, 0.5)
    expect_equal(r["p"], c(p = r[["p"]]))
    expect_error(r$p)
    swapped <- function(d) { z <- provider(d); z[c("a", "b")] <- z[c("b", "a")]; z }
    s <- missingmed:::.mm_d4_pool(imps, swapped, mode)
    expect_equal(as.vector(r), as.vector(s))
    expect_identical(s@stacked_branch, "b")
  }
  rows[,] <- 4
  tie <- missingmed:::.mm_d4_pool(imps, provider)
  expect_identical(tie@stacked_branch, "a")
  expect_false(tie@branch_mix)
  expect_equal(tie@p_branch_a, 1)
  for (mode in c("fixed", "own")) {
    bad <- function(d) { z <- provider(d); if (nrow(d) == 1L && d$id == 2) z["k_a"] <- 2; z }
    expect_error(missingmed:::.mm_d4_pool(imps, bad, mode), "(single k|different number)")
  }
})

test_that("generic union controls fail closed before full or nested null fitting", {
  fit <- t5_fit()
  calls <- 0L
  local_mocked_bindings(.mm_sem_fit = function(...) { calls <<- calls + 1L })
  base <- "M ~ a*X + u*C; Y ~ b*M + v*X + w*C; C ~~ z*C; X ~~ q*X"
  # 2^6 and 2^7 potential combinations; neither is delegated without a ledger.
  six <- "a*u == 0; b*v == 0; w*z == 0; a*v == 0; b*w == 0; u*q == 0"
  for (con in c("a*b == 0", "a*b == 0; a*b == 0", six,
    paste(six, "z*q == 0", sep = ";"), "ab := a*b; ab == 0")) {
    model <- paste(base, con, sep = ";")
    expect_error(t5_direct(model = model), "completeness")
    src <- fit@source
    src@model <- model
    changed <- fit
    changed@source <- src
    for (mode in c("own", "fixed")) {
      expect_error(infer(changed, type = "mbco", ariv = mode), "completeness")
    }
  }
  # A provably singular null is refused geometrically, not excluded by error text.
  expect_error(t5_direct(model = paste(base, "a == z + q", sep = ";")), "infeasible")
  expect_equal(calls, 0L)
})

test_that("stored fixture cross-check retains separate legacy and df provenance", {
  fx <- readRDS(test_path("fixtures", "mbco-d4-medsim-0.5.1.rds"))
  for (case in fx$cases) for (mode in c("fixed", "own")) {
    model <- paste("M ~", paste(attr(terms(case$formula_m), "term.labels"), collapse = " + "),
      "; Y ~", paste(attr(terms(case$formula_y), "term.labels"), collapse = " + "))
    sem <- t5_direct(case$implist, model = model, ariv = mode)
    glm <- mbco_d4(case$implist, case$formula_y, case$formula_m,
      treatment = "X", mediator = "M", ariv = mode)
    for (nm in names(S7::S7_data(glm))) {
      expect_equal(sem[[nm]], glm[[nm]], tolerance = 1e-7)
    }
    expect_identical(sem@stacked_branch, case$stacked_branch)
    expect_identical(sem@branch_mix, case$branch_mix)
    expect_equal(sem@p_branch_a, case$p_branch_a)
    for (nm in names(case$expected[[mode]])) {
      expect_equal(glm[[nm]], case$expected[[mode]][[nm]], tolerance = 1e-10)
    }
    if (mode == "own") {
      # The copied driver calls today's helper: arithmetic check, NOT a df oracle.
      old <- legacy_d4_mbco(case$implist, case$formula_y, case$formula_m,
        gaussian(), gaussian(), "X", "M")
      for (nm in names(old)) expect_equal(glm[[nm]], old[[nm]], tolerance = 1e-10)
      for (nm in names(case$legacy_own)) {
        expect_equal(old[[nm]], case$legacy_own[[nm]], tolerance = 1e-10)
      }
    }
  }
})

test_that("binary covariates match numeric coding but three-level factors refuse", {
  d <- t5_data
  d$C <- factor(iris$Species == "setosa")
  coded <- d
  coded$C <- as.numeric(d$C) - 1
  expect_equal(as.vector(t5_direct(list(d, d))), as.vector(t5_direct(list(coded, coded))),
    tolerance = 1e-7)
  d$C <- iris$Species
  expect_error(t5_direct(list(d, d)), "three|two|2-level|levels")
})

test_that("full improper diagnostics retain medfit's character payload and warn once", {
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    warning("improper solution: residual variance", call. = FALSE)
    list(fit = NULL, n_obs = nrow(d), improper = "residual variance")
  }, .mm_sem_mbco = function(fit, a, b) list(tests = data.frame(
    constraint = paste(c(a, b), "== 0"), f = c(1, 2),
    diff_ll = c(1, 9), converged = TRUE)))
  p <- missingmed:::.mm_sem_provider(t5_model, "X", "M", "Y")
  expect_identical(attr(p(t5_data), "improper"), "full")
  w <- capture_warnings(r <- t5_direct())
  expect_length(w, 1L)
  expect_match(w, "imputation 1.*full.*imputation 2.*full.*stacked data.*full")
  expect_true(is.finite(r[["p"]]))
})

test_that("remaining observed public input refusals retain their messages", {
  imps <- list(t5_data, t5_data)
  expect_error(t5_direct(list()), "at least 2 imputations")
  expect_error(t5_direct(imps[1]), "at least 2 imputations")
  for (model in c("M ~ C; Y ~ M + X", "M ~ X; Y ~ X")) {
    expect_error(t5_direct(model = model), "(no regression|does not regress)")
  }
  for (model in c("M ~ 0.5*X; Y ~ M + X", "M ~ 0*X; Y ~ M + X",
    "M ~ X; Y ~ 0*M + X")) expect_error(t5_direct(model = model), "path.*fixed")
  expect_error(t5_direct(model = "M ~ p*X; Y ~ p*M + X"), "same label")
  expect_error(t5_direct(model = 1), "single lavaan model syntax string")
  expect_error(t5_direct(model = "M ~~~ X"), "not valid lavaan syntax")
  expect_error(t5_direct(model = "M ~ X; Y ~ M + Z"), "Variable 'Z'")
  bad <- imps
  bad[[2]]$M[3] <- NA
  expect_error(t5_direct(bad), "Imputation 2.*missing values.*'M'")
  bad <- imps
  bad[[2]]$extra <- 1
  expect_error(t5_direct(bad), "same columns.*imputation 2")
  expect_error(t5_direct(list(t5_data, t5_data[-1, ])), "same number of rows")
  expect_error(t5_direct(fit_args = list(1)), "fit_args.*named list")
  expect_error(mbco_d4(imps, Y ~ M + X, M ~ X, model = t5_model,
    treatment = "X", mediator = "M", outcome = "Y"), "cannot be combined")
  expect_error(t5_direct(family_y = binomial()), "cannot be combined")
  expect_error(mbco_d4(imps, model = t5_model, treatment = "X", mediator = "M"),
    "outcome.*required")
  expect_error(mbco_d4(imps, model = t5_model, treatment = "M", mediator = "M",
    outcome = "Y"), "different variables")
  expect_error(mbco_d4(imps, Y ~ M + X, M ~ X, treatment = "X", mediator = "M",
    outcome = "Y"), "apply to `model`")
  r <- t5_direct()
  expect_equal(r@m, 2)
  expect_equal(r@k, 1)
  expect_equal(as.vector(t5_direct(setNames(imps, c("one", "two")))), as.vector(r))
})

test_that("parallel mediator and direct indicator paths retain separate null oracles", {
  d <- t5_data
  names(d)[4] <- "M2"
  cases <- list(list(d = d, x = "X", m = "M", y = "Y",
    model = "M ~ a*X; M2 ~ X; Y ~ b*M + M2 + X"),
    list(d = lavaan::HolzingerSwineford1939, x = "x1", m = "L", y = "x9",
      model = "L =~ x4 + x5 + x6; L ~ a*x1; x9 ~ b*L + x1 + x4"))
  for (case in cases) {
    p <- missingmed:::.mm_sem_provider(case$model, case$x, case$m, case$y)
    got <- p(case$d)
    ll <- function(model) as.numeric(lavaan::fitMeasures(
      lavaan::sem(model, data = case$d, fixed.x = FALSE), "logl"))
    full <- ll(case$model)
    for (branch in c("a", "b")) {
      null <- ll(paste(case$model, paste(branch, "== 0"), sep = ";"))
      expect_lt(abs(-2 * got[[branch]] - 2 * (full - null)), 1e-7)
    }
    expect_equal(unname(got[c("k_a", "k_b")]), c(1, 1))
    r <- mbco_d4(list(case$d, case$d), model = case$model,
      treatment = case$x, mediator = case$m, outcome = case$y)
    expect_true(is.finite(r[["p"]]))
    expect_equal(r[["D4"]], -2 * max(got[c("a", "b")]), tolerance = 1e-7)
    expect_equal(r[["r4"]], 0)
    if (case$m == "L") {
      extra_null <- ll(paste(case$model, "b == 0; x9 ~ 0*x4", sep = ";"))
      expect_gt(2 * (full - extra_null) - (-2 * got[["b"]]), 1)
    }
  }
})

test_that("resolved null improper labels propagate once through public inference", {
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    list(fit = NULL, n_obs = nrow(d), improper = character())
  }, .mm_sem_mbco = function(fit, a, b) {
    warning("improper solution: null variance", call. = FALSE)
    list(improper = "b", tests = data.frame(constraint = paste(c(a, b), "== 0"),
      f = c(1, 2), diff_ll = c(1, 9), converged = TRUE))
  })
  w <- capture_warnings(r <- t5_direct())
  expect_length(w, 1L)
  expect_match(w, "imputation 1.*imputation 2.*stacked data.*null variance")
  expect_match(w, "improper solution \\(b\\)")
  expect_true(is.finite(r[["p"]]))
})

test_that("unidentified null warnings require matching branch diagnostic refits", {
  full <- missingmed:::.mm_sem_fit("M ~ a*X+C; Y ~ b*M+X+C", t5_data)$fit
  original <- medfit::mbco_sem
  tab <- original(full, "a", "b")$tests
  target <- "b"
  bad <- NULL
  attribute_nulls <- function() missingmed:::.mm_sem_attribute_nulls(
    full, "a", "b", list(tests = tab), t5_data)
  local_mocked_bindings(.mm_sem_refit_diagnostics = function(fit, label, d) {
    i <- match(label, c("a", "b"))
    if (identical(bad, paste0("error", label))) stop("post-fit covariance failure")
    list(f = tab$f[i] + if (identical(bad, label)) 1 else 0,
      n_obs = fit@n_obs - if (identical(bad, "rows")) 1 else 0,
      improper = if (label %in% target) "null variance" else character())
  })
  for (target in list("a", "b", c("a", "b"))) {
    got <- attribute_nulls()
    expect_identical(got$improper, target)
    expect_equal(got$tests, tab)
  }
  target <- character()
  expect_error(attribute_nulls(),
    "[Uu]nresolved.*attribution")
  target <- "b"
  for (bad in c("a", "b", "rows", "errora", "errorb")) {
    expect_error(attribute_nulls(),
      "diagnostic refit|attribution")
  }
})

test_that("exported diagnostic refits match medfit nulls on stored inputs", {
  for (means in c("", "; M ~ 1; Y ~ 1")) {
    d <- t5_data
    for (factor_covariate in c(FALSE, TRUE)) {
      if (factor_covariate) d$C <- factor(iris$Species == "setosa")
      full <- missingmed:::.mm_sem_fit(paste0("M ~ a*X+C; Y ~ b*M+X+C", means), d)$fit
      tab <- medfit::mbco_sem(full, "a", "b")$tests
      for (i in 1:2) {
        refit <- missingmed:::.mm_sem_refit_diagnostics(full, c("a", "b")[i], d)
        expect_equal(refit$n_obs, full@n_obs)
        expect_lt(abs(full@n_obs * (refit$f - full@f) - tab$diff_ll[i]), 1e-7)
        expect_length(refit$improper, 0)
      }
    }
  }
})

test_that("null attribution uses refit identity rather than warning count in both APIs", {
  fit <- t5_fit()
  original_mbco <- missingmed:::.mm_sem_mbco
  original_refit <- missingmed:::.mm_sem_refit_diagnostics
  target <- "b"
  local_mocked_bindings(.mm_sem_mbco = function(fit, a, b) {
    result <- original_mbco(fit, a, b)
    result$improper <- character() # An empty future diagnostic field is not attribution.
    # Exactly one warning, even when both nulls are flagged.
    warning("improper solution: null variance", call. = FALSE)
    result
  }, .mm_sem_refit_diagnostics = function(fit, label, d) {
    result <- original_refit(fit, label, d)
    branch <- if (label == "mm_a") "a" else "b"
    result$improper <- if (branch %in% target) "null variance" else character()
    result
  })
  for (target in list("a", "b", c("a", "b"))) {
    for (mode in c("own", "fixed")) {
      for (api in c("direct", "infer")) {
        w <- capture_warnings(r <- if (api == "direct") t5_direct(ariv = mode) else
          infer(fit, type = "mbco", ariv = mode))
        expect_length(w, 1L)
        expected <- paste0("improper solution (", paste(target, collapse = ", "), ")")
        expect_true(grepl(expected, w, fixed = TRUE))
        expect_match(w, "imputation 1.*imputation 2.*stacked data")
        expect_true(is.finite(r[["p"]]))
      }
    }
  }
  target <- character()
  expect_error(t5_direct(), "imputation 1.*[Uu]nresolved null-warning attribution")
  expect_error(infer(fit, type = "mbco"),
    "imputation 1.*[Uu]nresolved null-warning attribution")
})

test_that("parser normalization cannot admit explicitly excluded syntax", {
  for (case in list(c("M ~ c(a)*X; Y ~ b*M + X", "c\\(\\)"),
    c('M ~ label("a")*X; Y ~ b*M + X', "label\\(\\)"),
    c("M + C ~ X; Y ~ M + X", "multi-lhs"))) {
    expect_error(t5_direct(model = case[1]), case[2])
  }
})

test_that("improper flags without emitted warnings still warn once by dataset", {
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    list(fit = NULL, n_obs = nrow(d), improper = "residual variance")
  }, .mm_sem_mbco = function(fit, a, b) list(tests = data.frame(
    constraint = paste(c(a, b), "== 0"), f = c(1, 2),
    diff_ll = c(1, 9), converged = TRUE)))
  w <- capture_warnings(r <- t5_direct())
  expect_length(w, 1L)
  expect_match(w, "imputation 1.*full.*imputation 2.*full.*stacked data.*full")
  expect_true(is.finite(r[["p"]]))
})

test_that("unused binary levels cannot yield a silent constant-covariate result", {
  d <- t5_data
  d$C <- factor(rep("only", nrow(d)), levels = c("only", "unused"))
  expect_error(t5_direct(list(d, d)), "(variance|constant|singular|level|positive definite)")
})

test_that("full-fit failures and dropped rows propagate through both public APIs", {
  fit <- t5_fit()
  index <- 0L
  target <- 1L
  failure <- "optimizer"
  local_mocked_bindings(.mm_sem_fit = function(model, d) {
    index <<- index + 1L
    if (index == target && failure != "rows") stop(paste(failure, "failure"))
    list(fit = NULL, n_obs = nrow(d) - as.integer(index == target), improper = FALSE)
  }, .mm_sem_mbco = function(fit, a, b) list(tests = data.frame(
    constraint = paste(c(a, b), "== 0"), f = c(1, 2),
    diff_ll = c(1, 9), converged = TRUE)))
  for (target in 1:3) for (failure in c("optimizer", "post-fit covariance", "rows")) {
    where <- if (target == 3L) "stacked data" else paste("imputation", target)
    detail <- if (failure == "rows") "dropped observations" else paste0("full model.*", failure)
    for (mode in c("own", "fixed")) for (invoke in list(
      function() t5_direct(ariv = mode), function() infer(fit, type = "mbco", ariv = mode))) {
      index <- 0L
      expect_error(invoke(), paste0(where, ".*", detail))
    }
  }
})
