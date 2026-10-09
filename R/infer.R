#' Inference on the indirect effect under multiple imputation
#'
#' Computes inference for the indirect (mediated) effect from a fitted
#' missingmed pipeline, dispatching to one of two engines:
#'
#' * `type = "mc"` — Monte-Carlo / distribution-of-the-product confidence
#'   interval via [RMediation::ci_mediation_data()] applied to the **pooled**
#'   named [medfit::MediationData]. When the outcome model has a
#'   treatment-by-mediator interaction (`Y ~ X * M + ...`), the indirect effect
#'   is \eqn{a (b + \theta_3 x)}, which depends on the treatment level \eqn{x};
#'   set `treatment_level` to choose it. The interval then comes from
#'   [RMediation::ci()] on the pooled estimates and pooled covariance of
#'   \eqn{(a, b, \theta_3)}.
#' * `type = "mbco"` — **D4-stacked MBCO** likelihood-ratio test of
#'   \eqn{H_0: a b = 0}, computed from the per-imputation datasets (MBCO does not
#'   commute with Rubin's rules; see [per_imputation_list()]). The engine is
#'   [mbco_d4()]; see there for `ariv`, the branch diagnostics and the cost.
#'   At least two imputations are required. It also works for
#'   `engine = "lavaan"` fits (including a latent mediator), with lavaan doing
#'   the refits: the tested paths are the structural regressions `mediator ~
#'   treatment` and `outcome ~ mediator`. Only `estimator = "ML"` (the default)
#'   is supported; `MLR`, `MLM`, `WLSMV`, `group`, `ordered`, `sampling.weights`
#'   and `method = "ipw"` are refused, naming the option. A refit that did not
#'   converge stops the test, naming the dataset, the branch and the model.
#'
#' @param object An [MDMediationFit] (supports both `"mc"` and `"mbco"`) or an
#'   [MDMediationResult] (supports `"mc"`).
#' @param ... Method arguments: `type` (inference type, `"mc"` (default) or
#'   `"mbco"`), `level` (confidence level for `"mc"`; defaults to the
#'   object's `@conf_level`, itself `0.95` unless set in [set_md_mediation()]),
#'   `n.mc`
#'   (Monte-Carlo draws for `"mc"`, default `1e5`), and `ariv` (for `"mbco"`:
#'   `"fixed"` (default) tests every imputation on the branch the stacked
#'   constrained fit chose; `"own"` uses each imputation's own winning branch
#'   and reproduces missingmed 0.4.0 on full-rank designs; see [mbco_d4()]),
#'   and `treatment_level` (for `"mc"` on a model with an `X:M` term, and
#'   only there: the treatment level \eqn{x} at which the indirect effect
#'   \eqn{a (b + \theta_3 x)} is evaluated, that is, the effect of a one-unit
#'   increase in X through M with X held at \eqn{x} in the outcome model. For
#'   a 0/1 treatment, `1` gives the total natural indirect effect and `0` the
#'   pure natural indirect effect. Required for such models; an error
#'   otherwise). Any other argument is an error, so a misspelled one (say
#'   `conf.level`) is not silently dropped.
#' @return For `"mc"`, the list returned by [RMediation::ci_mediation_data()]
#'   (`CI`, `Estimate`, `SE`, `MC.Error`); for a model with an `X:M` term, the
#'   same elements plus `Estimand`, the formula the interval is for.
#'   For `"mbco"`, an [MbcoMIResult]: the named numeric `c(D4, p, r4, nu, d_S)`
#'   (index it with `r["p"]` or `r[["p"]]`) with the branch diagnostics as
#'   properties.
#' @seealso [run()], [pool()], [per_imputation_list()], [mbco_d4()]
#' @examples
#' set.seed(1)
#' n <- 200
#' d <- data.frame(X = rnorm(n), C = rnorm(n))
#' d$M <- 0.4 * d$X + 0.3 * d$C + rnorm(n)
#' d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
#' d$M[sample(n, 30)] <- NA
#' d$Y[sample(n, 30)] <- NA
#' imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
#' fit <- run(set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
#'   treatment = "X", mediator = "M"
#' ))
#' r <- infer(fit, type = "mbco", ariv = "fixed")
#' r
#' r[["p"]]
#' @importFrom RMediation ci_mediation_data
#' @export
#' @name infer
infer <- S7::new_generic("infer", "object")

S7::method(infer, MDMediationFit) <- function(object, type = c("mc", "mbco"),
                                              level = NULL, n.mc = 1e5,
                                              ariv = c("fixed", "own"),
                                              treatment_level = NULL, ...) {
  # missing() is only reliable before an argument is reassigned, so read it first.
  supplied <- c(level = !missing(level), n.mc = !missing(n.mc),
    treatment_level = !missing(treatment_level), ariv = !missing(ariv))
  type <- match.arg(type)
  ariv <- match.arg(ariv)
  .check_infer_dots(...)
  .warn_ignored(supplied, type)
  # NULL (not 0.95) is the default so that "unspecified" is distinguishable from
  # "specified as 0.95": an explicit level= still wins, and otherwise the level
  # the user set once on the data object is honoured instead of ignored.
  level <- level %||% object@conf_level
  if (type == "mc") {
    pooled <- pool(object)@pooled
    return(.mc_interval(pooled, level, n.mc, treatment_level))
  }
  # mbco: D4-stacked over the per-imputation datasets
  src <- object@source
  if (!inherits(src, "missingmed::MDMediationData") && !S7::S7_inherits(src, MDMediationData)) {
    stop("MBCO needs the originating MDMediationData (imputed datasets). ",
      "Run infer() on the MDMediationFit returned by run().", call. = FALSE)
  }
  if (identical(src@method, "ipw")) {
    stop("MBCO inference for IPW is not yet implemented. Use type = \"mc\" for ",
      "IPW objects (weighted Monte-Carlo CI).", call. = FALSE)
  }
  implist <- mice::complete(src@data, action = "all")
  if (identical(object@engine, "lavaan")) {
    .mm_lav_check_mbco(src)
    return(.mm_d4_pool(implist, .mm_lav_provider(
      src@model, src@treatment, src@mediator, src@outcome, src@fit_args
    ), ariv))
  }
  .mm_d4_mbco(implist,
    .expand_dot(src@formula_y, src@original_data),
    .expand_dot(src@formula_m, src@original_data),
    src@family_y, src@family_m, src@treatment, src@mediator, ariv = ariv)
}

S7::method(infer, MDMediationResult) <- function(object, type = c("mc", "mbco"),
                                                 level = NULL, n.mc = 1e5,
                                                 treatment_level = NULL, ...) {
  type <- match.arg(type)
  level <- level %||% object@conf_level
  if (type == "mbco") {
    stop("MBCO does not commute with Rubin's rules; it needs the per-imputation ",
      "fits. Call infer(type = \"mbco\") on the MDMediationFit from run(), not ",
      "on the pooled MDMediationResult.", call. = FALSE)
  }
  .check_infer_dots(...)
  .mc_interval(object@pooled, level, n.mc, treatment_level)
}

# infer()'s `...` exists only because the S7 generic needs it. Anything that
# lands there is a misspelled or misplaced argument (`conf.level = 0.9`,
# `nmc = 1e4`) that would otherwise be dropped while the default is used.
# Arguments that are valid for infer() but do not apply to the chosen `type`:
# MBCO is a likelihood-ratio test of a * b = 0, with no interval (`level`), no
# Monte Carlo draws (`n.mc`) and no treatment level (`treatment_level`); `ariv`
# applies only to MBCO. Warn once, naming them, instead of ignoring them.
.warn_ignored <- function(supplied, type) {
  unused <- if (identical(type, "mbco")) {
    c("level", "n.mc", "treatment_level")
  } else {
    "ariv"
  }
  hit <- intersect(unused, names(supplied)[supplied])
  if (length(hit)) {
    warning("Ignored for type = \"", type, "\": ",
      paste0("`", hit, "`", collapse = ", "), ".",
      call. = FALSE
    )
  }
  invisible(hit)
}

.check_infer_dots <- function(...) {
  if (...length() == 0L) {
    return(invisible(TRUE))
  }
  # ...names() reads the names without evaluating the values.
  nms <- ...names() %||% rep("", ...length())
  nms[is.na(nms) | !nzchar(nms)] <- "<unnamed>"
  stop("Unused argument", if (length(nms) > 1L) "s", " in `infer()`: ",
    paste0("`", nms, "`", collapse = ", "), ". The arguments are `type`, ",
    "`level`, `n.mc`, `treatment_level` and, for an MDMediationFit, `ariv`.",
    call. = FALSE
  )
}

# Monte Carlo interval for the indirect effect of a pooled fit. Without an X:M
# term the indirect effect is a * b, and RMediation::ci_mediation_data() handles
# the pooled MediationData directly. With X:M it is a * (b + theta3 * x): the
# effect of a one-unit increase in X on Y through M, with X held at x in the
# outcome model. x has no default, because the answer depends on it (for a 0/1
# treatment, x = 1 is the total natural indirect effect, x = 0 the pure one).
# The draws come from the pooled estimates and the pooled (Rubin total)
# covariance of (a, b, theta3); its a-by-b block is not zero, because the
# between-imputation part couples the two models.
.mc_interval <- function(pooled, level, n.mc, treatment_level) {
  # RMediation accepts level 0 and 1 (a zero-width interval, and the range of
  # the draws) and fails obscurely on n.mc = 1, so both are checked here.
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) ||
    level <= 0 || level >= 1) {
    stop("`level` must be a single number in (0, 1).", call. = FALSE)
  }
  if (!is.numeric(n.mc) || length(n.mc) != 1L || !is.finite(n.mc) ||
    n.mc < 2 || n.mc != round(n.mc)) {
    stop("`n.mc` must be a single whole number of at least 2.", call. = FALSE)
  }
  is_int <- .has_xm(pooled)
  # An aliased path coefficient (its predictor collinear with others, or
  # constant, in some imputation) pools to NA, and RMediation then fails
  # inside eigen(). Only the terms the interval uses matter.
  keep <- c("a", "b", if (is_int) "theta3")
  bad <- keep[is.na(pooled@estimates[keep]) |
    is.na(diag(pooled@vcov)[keep])]
  if (length(bad)) {
    stop("The pooled ", paste0("`", bad, "`", collapse = ", "), " is NA, so ",
      "the indirect effect has no interval. A coefficient is NA when its ",
      "predictor is aliased (collinear with other predictors, or constant) ",
      "in at least one imputation; see the tidy table from pool().",
      call. = FALSE
    )
  }
  if (!is_int) {
    if (!is.null(treatment_level)) {
      stop("`treatment_level` applies only to models with a treatment-by-",
        "mediator interaction in the outcome model; this model has none, so ",
        "the indirect effect is a * b at every treatment level. Drop the ",
        "argument.", call. = FALSE)
    }
    return(ci_mediation_data(pooled, level = level, type = "MC", n.mc = n.mc))
  }
  if (is.null(treatment_level)) {
    stop("The outcome model has a treatment-by-mediator interaction, so the ",
      "indirect effect a * (b + theta3 * x) depends on the treatment level x. ",
      "Set `treatment_level` (for a 0/1 treatment, 1 gives the total natural ",
      "indirect effect and 0 the pure natural indirect effect).", call. = FALSE)
  }
  if (!is.numeric(treatment_level) || length(treatment_level) != 1L ||
      !is.finite(treatment_level)) {
    stop("`treatment_level` must be a single finite number.", call. = FALSE)
  }
  keep <- c("a", "b", "theta3")
  quant <- eval(bquote(~ a * (b + theta3 * .(treatment_level))))
  r <- RMediation::ci(pooled@estimates[keep],
    Sigma = pooled@vcov[keep, keep, drop = FALSE], quant = quant,
    alpha = 1 - level, type = "MC", n.mc = n.mc
  )
  list(
    CI = r[[1L]], Estimate = r$Estimate, SE = r$SE, MC.Error = r$MCError,
    Estimand = paste0("a * (b + theta3 * ", format(treatment_level), ")")
  )
}
