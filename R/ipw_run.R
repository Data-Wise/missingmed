# IPW estimator: estimate inverse-probability-of-observation weights and fit the
# mediation model once on the reweighted complete cases. Called by run() when
# MDMediationData@method == "ipw". See SPEC-ipw-phase1.

#' Estimate IPW weights for the complete-case mediation fit
#'
#' Internal. Returns a full-length weight vector (`NA` for incomplete rows).
#' @param object An [MDMediationData] with `@method == "ipw"`.
#' @return Numeric vector, length `nrow(object@data)`.
#' @keywords internal
#' @noRd
.ipw_weights <- function(object) .ipw_weights_info(object)$w

#' IPW weights plus the quantities their estimation depends on
#'
#' Internal. The weights of [.ipw_weights()] and, for a variance that accounts
#' for estimating them (docs/specs/NOTE-ipw-weight-score-stacking-2026-10-09.md),
#' the fitted missingness models. `info$blocks` has one entry per fitted model:
#' `kind` is `"miss"` (P(R = 1 | z), the denominator) or `"num"` (the
#' stabilization numerator), `var` the variable of a per-variable model (`NA`
#' for the joint model), `model` the `glm`, and `p` the full-length fitted
#' probability (`NA` where a predictor is missing). `info$cc` flags the complete
#' cases, `info$trimmed` the complete cases whose weight was capped, and
#' `info$w_untrimmed` the weights before the cap.
#' @inheritParams .ipw_weights
#' @return A list with `w` (as [.ipw_weights()]) and `info`.
#' @keywords internal
#' @noRd
.ipw_weights_info <- function(object) {
  data <- as.data.frame(object@data)
  n <- nrow(data)
  model_vars <- intersect(.model_vars(object), names(data))

  # Complete-case indicator over the model variables.
  cc <- stats::complete.cases(data[, model_vars, drop = FALSE])
  R <- as.integer(cc)
  # Checked before any model is fit: with no complete case there is nothing to
  # reweight, and the glm calls below would only warn on a constant response.
  if (!any(cc)) {
    stop("No complete cases: every row has a missing value in at least one ",
      "model variable (", paste(model_vars, collapse = ", "), "), so IPW has ",
      "nothing to reweight. Use method = \"mi\".",
      call. = FALSE
    )
  }

  treatment <- object@treatment
  stabilize <- isTRUE(object@weight_stabilize)
  wf <- object@weight_formula
  per_var <- is.list(wf) && !is.null(names(wf))
  if (per_var) {
    unknown <- setdiff(names(wf), names(data))
    if (length(unknown)) {
      stop("`weight_formula` names variables not in the data: ",
        paste0("'", unknown, "'", collapse = ", "), ".",
        call. = FALSE
      )
    }
  }
  # A per-variable specification must cover every incomplete model variable:
  # rows are selected on all of them, so a missing one leaves its share of the
  # selection uncorrected and still returns plausible estimates.
  if (per_var) {
    incomplete <- model_vars[vapply(data[model_vars], anyNA, logical(1))]
    uncovered <- setdiff(incomplete, names(wf))
    if (length(uncovered)) {
      stop("`weight_formula` must name every incomplete model variable, but ",
        paste0("'", uncovered, "'", collapse = ", "), " ",
        if (length(uncovered) > 1L) "are" else "is", " missing from it. ",
        "Complete cases are selected on all of them, so weights that omit one ",
        "leave that selection uncorrected. Add an entry for each, e.g. `",
        uncovered[1L], " = ~ <predictors of missingness>`.",
        call. = FALSE
      )
    }
  }
  # No missing values: P(R = 1 | Z) = 1 and every weight is 1. Fitting the
  # missingness model to a constant response would only warn that it did not
  # converge.
  if (all(cc)) {
    return(list(w = rep(1, n), info = list(
      cc = cc, stabilize = stabilize, per_var = per_var, blocks = list(),
      trimmed = rep(FALSE, n), cap = NA_real_, w_untrimmed = rep(1, n)
    )))
  }
  blocks <- list()

  # Probability of being observed, P(R = 1 | Z), per row.
  if (per_var) {
    # Per-variable (sequential factorization): P(complete) = prod_V P(R_V = 1).
    p <- rep(1, n)
    p_num <- rep(1, n)
    for (v in names(wf)) {
      Rv <- as.integer(!is.na(data[[v]]))
      dd <- data
      dd[[".R_v"]] <- Rv
      rhs <- attr(stats::terms(wf[[v]]), "term.labels")
      # The user's formula environment, so a name in it (a constant `k` in
      # `I(C * k)`) is found, and not shadowed by a local here such as `n`.
      mod <- stats::glm(
        stats::reformulate(rhs, ".R_v", env = environment(wf[[v]])),
        data = dd, family = stats::binomial()
      )
      p_v <- .ipw_prob(mod, dd)
      p <- p * p_v
      blocks[[length(blocks) + 1L]] <- list(kind = "miss", var = v, model = mod,
        p = p_v)
      if (stabilize) {
        num <- stats::glm(stats::reformulate(treatment, ".R_v"), data = dd,
          family = stats::binomial())
        q_v <- .ipw_prob(num, dd)
        p_num <- p_num * q_v
        blocks[[length(blocks) + 1L]] <- list(kind = "num", var = v, model = num,
          p = q_v)
      }
    }
  } else {
    # Joint complete-case model. Predictors: an explicit weight_formula RHS, else
    # all fully-observed model variables (the MAR drivers).
    wf_env <- environment()
    if (inherits(wf, "formula")) {
      rhs <- attr(stats::terms(wf), "term.labels")
      wf_env <- environment(wf) # as for the per-variable formulas above
    } else {
      fully_obs <- model_vars[vapply(data[model_vars], function(x) !anyNA(x), logical(1))]
      rhs <- setdiff(fully_obs, character(0))
      if (length(rhs) == 0L) rhs <- treatment
    }
    dd <- data
    dd[[".R_ind"]] <- R
    mod <- stats::glm(stats::reformulate(rhs, ".R_ind", env = wf_env),
      data = dd, family = stats::binomial())
    p <- .ipw_prob(mod, dd)
    blocks[[1L]] <- list(kind = "miss", var = NA_character_, model = mod, p = p)
    p_num <- rep(1, n)
    if (stabilize) {
      num <- stats::glm(stats::reformulate(treatment, ".R_ind"), data = dd,
        family = stats::binomial())
      p_num <- .ipw_prob(num, dd)
      blocks[[2L]] <- list(kind = "num", var = NA_character_, model = num,
        p = p_num)
    }
  }

  # NB: use if/else, not ifelse() — the condition is scalar, so ifelse() would
  # collapse the result to length 1.
  w <- if (stabilize) p_num / p else 1 / p
  # A complete case with an undefined probability means a predictor of the
  # missingness model is itself incomplete on that row -- a specification error,
  # never something to drop silently.
  if (anyNA(w[cc])) {
    stop("The missingness model cannot be evaluated on ", sum(is.na(w[cc])),
      " complete-case row(s): a predictor of `weight_formula` (or the treatment ",
      "used for stabilization) is incomplete there. Use fully observed ",
      "predictors, or impute them first.",
      call. = FALSE
    )
  }
  w[!cc] <- NA_real_ # incomplete rows are dropped from the fit
  w_untrimmed <- w

  # Trim at the requested upper quantile (computed on complete cases).
  trimmed <- rep(FALSE, n)
  cap <- NA_real_
  if (object@weight_trim < 1) {
    cap <- stats::quantile(w[cc], probs = object@weight_trim, names = FALSE)
    trimmed <- cc & w > cap
    w[trimmed] <- cap
  }
  list(w = w, info = list(
    cc = cc, stabilize = stabilize, per_var = per_var, blocks = blocks,
    trimmed = trimmed, cap = cap, w_untrimmed = w_untrimmed
  ))
}

#' IPW run path
#' @importFrom sandwich vcovHC
#' @keywords internal
#' @noRd
.ipw_run <- function(object, ...) {
  .check_engine(object@engine, "ipw")
  data <- as.data.frame(object@data)
  w_full <- .ipw_weights(object)
  cc <- !is.na(w_full)
  cc_data <- data[cc, , drop = FALSE]
  w_cc <- w_full[cc]

  if (identical(object@engine, "lavaan")) {
    if (...length() > 0L) {
      stop("`run()` takes no extra arguments for engine = \"lavaan\"; set ",
        "them with `fit_args` in set_md_mediation().",
        call. = FALSE
      )
    }
    .check_lavaan_ipw_args(object@fit_args, object@se_type)
    cc_data$.md_ipw_w <- w_cc
    res <- .md_fit_one(object, cc_data, "the IPW fit")
  } else {
    extra <- .md_extra_args(object, list(...), ipw = TRUE)
    res <- do.call(.md_fit_one, c(
      list(object, cc_data, "the IPW fit", weights = w_cc, se_type = object@se_type),
      extra
    ))
  }
  .md_warn_fits(list(res$warnings), object@engine)
  med <- res$fit
  if (inherits(med, "md_nonconverged")) {
    stop("engine \"lavaan\" did not converge on the IPW fit. Simplify the ",
      "model, or pass `fit_args` such as list(control = list(iter.max = 5000)).",
      call. = FALSE
    )
  }

  MDMediationFit(
    per_imputation = list(med),
    fits = list(),
    m = 1,
    engine = object@engine,
    conf_int = object@conf_int,
    conf_level = object@conf_level,
    weights = w_full,
    source = object
  )
}

# Full-length P(R = 1 | Z): predict() on the original frame keeps one value per
# row (NA where a predictor is NA), unlike fitted(), which drops those rows and
# silently misaligns the weights.
.ipw_prob <- function(mod, dd) {
  out <- tryCatch(
    stats::predict(mod, newdata = dd, type = "response"),
    error = function(e) {
      stop("The missingness model could not be evaluated on the full data: ",
        conditionMessage(e), ". This usually means a factor predictor has a ",
        "level that appears only on rows the model dropped. Use a predictor ",
        "that is observed across all rows, or collapse the rare level.",
        call. = FALSE
      )
    }
  )
  unname(out)
}
