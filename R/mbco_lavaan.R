# Log-likelihood provider for D4-stacked MBCO with engine = "lavaan"
# (SPEC-sem-mbco-2026-10-08.md, S1, S2, S5, S8). The pooling in
# .mm_d4_pool() is estimator-free; this supplies, per dataset, the lavaan
# log-likelihoods of the full model and of the a = 0 / b = 0 nulls.

# The `fit_args` carried to the null refits: all of them except those the
# provider sets itself. The nulls must be fit on the same footing as the full
# model: options that change the likelihood (`fixed.x`, `likelihood`,
# `conditional.x`, `missing`, ...) would otherwise be dropped from the nulls and
# make 2 * (ll_full - ll_null) compare two different likelihoods. Options the
# parameter table already decided (std.lv, auto.*, ...) are harmless to repeat.
.mm_lav_refit_args <- function(fit_args) {
  fit_args[!.lav_key(names(fit_args)) %in% c("se", "model", "data")]
}

# The row of the FITTED model's parameter table for `lhs ~ rhs`. Exactly one is
# required: none means the path is not in the model, more than one means a
# multi-group or repeated regression, where "the path" is not a single row.
.mm_lav_row <- function(pt, lhs, rhs, role) {
  hit <- which(pt$op == "~" & pt$lhs == lhs & pt$rhs == rhs)
  if (length(hit) != 1L) {
    stop("MBCO needs exactly one `", lhs, " ~ ", rhs, "` regression (the ", role,
      " path) in the lavaan model; found ", length(hit), ".",
      call. = FALSE
    )
  }
  # A path fixed to a value in the syntax (`M ~ 0.5*X`, `M ~ 0*X`) has nothing
  # to test: nulling it would remove no parameter.
  if (!is.na(pt$free[hit]) && pt$free[hit] == 0L) {
    stop("The `", lhs, " ~ ", rhs, "` path (the ", role, " path) is fixed in ",
      "the lavaan model, not estimated, so there is no parameter to test. Free ",
      "it, or use type = \"mc\".",
      call. = FALSE
    )
  }
  hit
}

# The fitted full model's parameter table with ONE row fixed to 0. Starting from
# parTable(<fitted model>) rather than lavaanify() keeps every default sem()
# applied; a bare lavaanify(auto = TRUE) table is not the table sem() fits for a
# latent model (more free parameters, an uninvertible information matrix).
.mm_lav_null <- function(fit, row, data, refit_args) {
  pt <- lavaan::parTable(fit)
  # `:=` rows define quantities from labels (the indirect effect a*b); they do
  # not enter the likelihood, and lavaan refuses one whose label is now fixed.
  keep <- pt$op != ":="
  row <- match(row, which(keep))
  pt <- pt[keep, , drop = FALSE]
  pt$free[row] <- 0L
  pt$ustart[row] <- 0
  pt[c("est", "se", "start")] <- NULL
  pt$free[pt$free > 0] <- seq_len(sum(pt$free > 0))
  do.call(lavaan::lavaan, c(list(model = pt, data = data, se = "none"), refit_args))
}

# Refuse before any fit the `fit_args` the lavaan MBCO does not support (S4).
# MLR is refused (SPEC-sem-mbco-2026-10-08.md, section 12): the T8b gate failed,
# and the scaled statistic was no better calibrated than the naive D4. The
# provider and the pooling still carry the scaled-difference code (.mm_lav_cd(),
# `scaling` in .mm_d4_pool()) so the gate harness (dev/sim-sem-mbco-mlr-*.R) can
# be rerun; options(missingmed.internal_mlr = TRUE) lifts the refusal for that
# harness and for tests only. It is not a public interface.
.mm_lav_is_mlr <- function(fa) {
  est <- .lav_arg(fa, "estimator")
  !is.null(est) && identical(toupper(as.character(est)), "MLR")
}

.mm_lav_check_args <- function(fa) {
  est <- .lav_arg(fa, "estimator")
  internal_mlr <- isTRUE(getOption("missingmed.internal_mlr")) && .mm_lav_is_mlr(fa)
  if (!is.null(est) && !identical(toupper(as.character(est)), "ML") && !internal_mlr) {
    stop("MBCO for engine = \"lavaan\" supports estimator = \"ML\" only; the ",
      "`fit_args` estimator is \"", est, "\". Robust tests (MLR, MLM) and ",
      "limited-information estimators (WLSMV, ...) are not supported: D4 pooling ",
      "of a scaled statistic is unvalidated (SPEC-sem-mbco-2026-10-08.md, S4). ",
      if (.mm_lav_is_mlr(fa)) {
        paste0("MLR was simulated and fails the size gate, with no gain over the ",
          "unscaled test (SPEC-sem-mbco-2026-10-08.md, section 12). ")
      },
      "Use estimator = \"ML\", or type = \"mc\".",
      call. = FALSE
    )
  }
  for (nm in c("ordered", "group", "sampling_weights")) {
    if (!is.null(.lav_arg(fa, nm))) {
      stop("MBCO for engine = \"lavaan\" does not support `fit_args` `",
        gsub("_", ".", nm), "`.",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

# The same, plus the model's a and b rows, for the MDMediationData of a lavaan
# fit (IPW is refused by infer() before this).
.mm_lav_check_mbco <- function(src) {
  .mm_lav_check_args(src@fit_args)
  .mm_lav_check_rows(src@model, src@treatment, src@mediator, src@outcome)
}

# One a row and one b row in the model, checked before any imputation is fit.
.mm_lav_check_rows <- function(model, treatment, mediator, outcome) {
  pt <- lavaan::lavaanify(model)
  .mm_lav_row(pt, mediator, treatment, "a")
  .mm_lav_row(pt, outcome, mediator, "b")
  invisible(TRUE)
}

# Satorra-Bentler (2001) scaling correction of a nested difference,
# cd = (df0 c0 - df1 c1) / (df0 - df1), where fit 0 is the null (more df) and
# fit 1 the full model. A saturated full model (df1 = 0) has no scaling factor
# and contributes 0.
.mm_scaling_cd <- function(c0, df0, c1, df1) {
  t1 <- if (df1 == 0) 0 else df1 * c1
  (df0 * c0 - t1) / (df0 - df1)
}

# A scaling correction that is not positive makes the scaled difference
# undefined (SB 2001 can go negative); refuse rather than pool it.
.mm_check_cd <- function(cd, branch) {
  if (!is.finite(cd) || cd <= 0) {
    stop("the scaled difference test for the ", branch, " null is undefined: its ",
      "Satorra-Bentler (2001) scaling correction is ", format(cd), ", not a positive ",
      "number. Use estimator = \"ML\", or simplify the model.",
      call. = FALSE
    )
  }
  invisible(cd)
}

# The scaling correction of the full-versus-null difference. The pooling checks
# it (.mm_check_cd) so the error can name the dataset.
.mm_lav_cd <- function(full, null) {
  m <- function(f) as.numeric(lavaan::fitMeasures(f, c("df", "chisq.scaling.factor")))
  mf <- m(full)
  mn <- m(null)
  .mm_scaling_cd(c0 = mn[2], df0 = mn[1], c1 = mf[2], df1 = mf[1])
}

.mm_lav_ll <- function(fit, branch) {
  if (!isTRUE(lavaan::lavInspect(fit, "converged"))) {
    stop("the ", branch, " lavaan model did not converge. Simplify the model, ",
      "or pass `fit_args` such as list(control = list(iter.max = 5000)).",
      call. = FALSE
    )
  }
  ll <- as.numeric(lavaan::fitMeasures(fit, "logl"))
  if (!is.finite(ll)) {
    stop("the ", branch, " lavaan model has a non-finite log-likelihood.",
      call. = FALSE
    )
  }
  ll
}

# model/outcome/fit_args as stored by set_md_mediation(engine = "lavaan").
.mm_lav_provider <- function(model, treatment, mediator, outcome, fit_args = list()) {
  force(model)
  mlr <- .mm_lav_is_mlr(fit_args)
  # lavaan's `se = "none"` (every fit here) silently switches MLR from observed
  # to expected information, which moves the Yuan-Bentler scaling factor by a few
  # percent (1.211 vs 1.247 in the T7 probe). Pin the MLR default, the one a
  # run() fit with standard errors uses, unless the user chose.
  if (mlr && is.null(.lav_arg(fit_args, "information"))) {
    fit_args <- c(fit_args, list(information = "observed"))
  }
  refit_args <- .mm_lav_refit_args(fit_args)
  function(d) {
    # The full fit is the one run() makes, so the nulls start from the same
    # model the user fitted.
    args_full <- fit_args[.lav_key(names(fit_args)) != "se"]
    full <- suppressWarnings(.lav_sem(model, d, c(args_full, list(se = "none"))))
    ll_full <- .mm_lav_ll(full, "full")
    pt <- lavaan::parTable(full)
    row_a <- .mm_lav_row(pt, mediator, treatment, "a")
    row_b <- .mm_lav_row(pt, outcome, mediator, "b")
    a0 <- suppressWarnings(.mm_lav_null(full, row_a, d, refit_args))
    b0 <- suppressWarnings(.mm_lav_null(full, row_b, d, refit_args))
    npar <- function(f) lavaan::lavInspect(f, "npar")
    out <- c(
      full = ll_full, a = .mm_lav_ll(a0, "a = 0"), b = .mm_lav_ll(b0, "b = 0"),
      k_a = npar(full) - npar(a0), k_b = npar(full) - npar(b0)
    )
    # MLR: the SB (2001) scaling correction of each null's difference (T7). The
    # pooling divides D4 by its mean over the winning branch.
    if (mlr) {
      out <- c(out,
        cd_a = .mm_lav_cd(full, a0), cd_b = .mm_lav_cd(full, b0)
      )
    }
    # An improper solution (a Heywood case, post.check failed) is not refused
    # (S6): the pooling warns once, naming the datasets.
    fits <- list(full = full, `a = 0` = a0, `b = 0` = b0)
    # lavInspect(, "post.check") itself warns on a failed check; the pooling
    # raises the one warning, so this one is silenced.
    ok <- function(f) isTRUE(suppressWarnings(lavaan::lavInspect(f, "post.check")))
    bad <- !vapply(fits, ok, NA)
    attr(out, "improper") <- names(fits)[bad]
    out
  }
}
