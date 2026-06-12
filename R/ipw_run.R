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
.ipw_weights <- function(object) {
  data <- as.data.frame(object@data)
  n <- nrow(data)
  model_vars <- unique(c(all.vars(object@formula_y), all.vars(object@formula_m)))
  model_vars <- intersect(model_vars, names(data))

  # Complete-case indicator over the model variables.
  cc <- stats::complete.cases(data[, model_vars, drop = FALSE])
  R <- as.integer(cc)

  treatment <- object@treatment
  stabilize <- isTRUE(object@weight_stabilize)
  wf <- object@weight_formula

  # Probability of being observed, P(R = 1 | Z), per row.
  if (is.list(wf) && !is.null(names(wf))) {
    # Per-variable (sequential factorization): P(complete) = prod_V P(R_V = 1).
    p <- rep(1, n)
    p_num <- rep(1, n)
    for (v in names(wf)) {
      Rv <- as.integer(!is.na(data[[v]]))
      dd <- data
      dd[[".R_v"]] <- Rv
      rhs <- attr(stats::terms(wf[[v]]), "term.labels")
      mod <- stats::glm(stats::reformulate(rhs, ".R_v"), data = dd,
        family = stats::binomial())
      p <- p * stats::fitted(mod)
      if (stabilize) {
        num <- stats::glm(stats::reformulate(treatment, ".R_v"), data = dd,
          family = stats::binomial())
        p_num <- p_num * stats::fitted(num)
      }
    }
  } else {
    # Joint complete-case model. Predictors: an explicit weight_formula RHS, else
    # all fully-observed model variables (the MAR drivers).
    if (inherits(wf, "formula")) {
      rhs <- attr(stats::terms(wf), "term.labels")
    } else {
      fully_obs <- model_vars[vapply(data[model_vars], function(x) !anyNA(x), logical(1))]
      rhs <- setdiff(fully_obs, character(0))
      if (length(rhs) == 0L) rhs <- treatment
    }
    dd <- data
    dd[[".R_ind"]] <- R
    mod <- stats::glm(stats::reformulate(rhs, ".R_ind"), data = dd,
      family = stats::binomial())
    p <- stats::fitted(mod)
    p_num <- if (stabilize) {
      stats::fitted(stats::glm(stats::reformulate(treatment, ".R_ind"), data = dd,
        family = stats::binomial()))
    } else {
      rep(1, n)
    }
  }

  # NB: use if/else, not ifelse() — the condition is scalar, so ifelse() would
  # collapse the result to length 1.
  w <- if (stabilize) p_num / p else 1 / p
  w[!cc] <- NA_real_ # incomplete rows are dropped from the fit

  # Trim at the requested upper quantile (computed on complete cases).
  if (object@weight_trim < 1) {
    cap <- stats::quantile(w[cc], probs = object@weight_trim, names = FALSE)
    w[cc & w > cap] <- cap
  }
  w
}

#' IPW run path
#' @keywords internal
#' @noRd
.ipw_run <- function(object, ...) {
  data <- as.data.frame(object@data)
  w_full <- .ipw_weights(object)
  cc <- !is.na(w_full)
  cc_data <- data[cc, , drop = FALSE]
  w_cc <- w_full[cc]

  med <- medfit::fit_mediation(
    formula_y = object@formula_y,
    formula_m = object@formula_m,
    data = cc_data,
    treatment = object@treatment,
    mediator = object@mediator,
    engine = object@engine,
    family_y = object@family_y,
    family_m = object@family_m,
    weights = w_cc,
    se_type = object@se_type,
    ...
  )

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
