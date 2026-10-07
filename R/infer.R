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
#'   At least two imputations are required.
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
#'   otherwise).
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
  type <- match.arg(type)
  ariv <- match.arg(ariv)
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
  .mm_d4_mbco(implist, src@formula_y, src@formula_m, src@family_y, src@family_m,
    src@treatment, src@mediator, ariv = ariv)
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
  .mc_interval(object@pooled, level, n.mc, treatment_level)
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
  is_int <- .has_xm(pooled)
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
