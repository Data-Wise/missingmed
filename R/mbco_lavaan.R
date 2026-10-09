# Log-likelihood provider for D4-stacked MBCO with engine = "lavaan"
# (SPEC-sem-mbco-2026-10-08.md, S1, S2, S5, S8). The pooling in
# .mm_d4_pool() is estimator-free; this supplies, per dataset, the lavaan
# log-likelihoods of the full model and of the a = 0 / b = 0 nulls.

# The refit options carried over from the user's `fit_args`: the ones that
# change how a model is estimated, not how its syntax is read. A parameter
# table already holds everything the syntax options decided (std.lv, auto.*,
# meanstructure, ...), so re-passing those would be redundant at best.
.mm_lav_refit_keys <- c("estimator", "information", "optim_method", "control")

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
  hit
}

# The fitted full model's parameter table with ONE row fixed to 0. Starting from
# parTable(<fitted model>) rather than lavaanify() keeps every default sem()
# applied; a bare lavaanify(auto = TRUE) table is not the table sem() fits for a
# latent model (more free parameters, an uninvertible information matrix).
.mm_lav_null <- function(fit, row, data, refit_args) {
  pt <- lavaan::parTable(fit)
  pt$free[row] <- 0L
  pt$ustart[row] <- 0
  pt[c("est", "se", "start")] <- NULL
  pt$free[pt$free > 0] <- seq_len(sum(pt$free > 0))
  do.call(lavaan::lavaan, c(list(model = pt, data = data, se = "none"), refit_args))
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
  keep <- .lav_key(names(fit_args)) %in% .mm_lav_refit_keys
  refit_args <- fit_args[keep]
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
    c(
      full = ll_full, a = .mm_lav_ll(a0, "a = 0"), b = .mm_lav_ll(b0, "b = 0"),
      k_a = npar(full) - npar(a0), k_b = npar(full) - npar(b0)
    )
  }
}
