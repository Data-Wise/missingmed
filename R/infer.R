#' Inference on the indirect effect under multiple imputation
#'
#' Computes inference for the indirect (mediated) effect from a fitted
#' missingmed pipeline, dispatching to one of two engines:
#'
#' * `type = "mc"` — Monte-Carlo / distribution-of-the-product confidence
#'   interval via [RMediation::ci_mediation_data()] applied to the **pooled**
#'   named [medfit::MediationData].
#' * `type = "mbco"` — **D4-stacked MBCO** likelihood-ratio test of
#'   \eqn{H_0: a b = 0}, computed from the per-imputation datasets (MBCO does not
#'   commute with Rubin's rules; see [per_imputation_list()]).
#'
#' @param object An [MDMediationFit] (supports both `"mc"` and `"mbco"`) or an
#'   [MDMediationResult] (supports `"mc"`).
#' @param type Inference type: `"mc"` (default) or `"mbco"`.
#' @param level Confidence level for `type = "mc"`. Defaults to `0.95`.
#' @param n.mc Monte-Carlo draws for `type = "mc"`. Defaults to `1e5`.
#' @param ... Unused.
#' @return For `"mc"`, the list returned by [RMediation::ci_mediation_data()].
#'   For `"mbco"`, a named numeric vector `c(D4, p, r4, nu, d_S)`.
#' @seealso [run()], [pool()], [per_imputation_list()]
#' @export
#' @name infer
infer <- S7::new_generic("infer", "object")

S7::method(infer, MDMediationFit) <- function(object, type = c("mc", "mbco"),
                                              level = 0.95, n.mc = 1e5, ...) {
  type <- match.arg(type)
  if (type == "mc") {
    pooled <- pool(object)@pooled
    return(RMediation::ci_mediation_data(pooled, level = level, type = "MC", n.mc = n.mc))
  }
  # mbco: D4-stacked over the per-imputation datasets
  src <- object@source
  if (!inherits(src, "missingmed::MDMediationData") && !S7::S7_inherits(src, MDMediationData)) {
    stop("MBCO needs the originating MDMediationData (imputed datasets). ",
      "Run infer() on the MDMediationFit returned by run().", call. = FALSE)
  }
  implist <- mice::complete(src@data, action = "all")
  .mm_d4_mbco(implist, src@formula_y, src@formula_m, src@family_y, src@family_m,
    src@treatment, src@mediator)
}

S7::method(infer, MDMediationResult) <- function(object, type = c("mc", "mbco"),
                                                 level = 0.95, n.mc = 1e5, ...) {
  type <- match.arg(type)
  if (type == "mbco") {
    stop("MBCO does not commute with Rubin's rules; it needs the per-imputation ",
      "fits. Call infer(type = \"mbco\") on the MDMediationFit from run(), not ",
      "on the pooled MDMediationResult.", call. = FALSE)
  }
  RMediation::ci_mediation_data(object@pooled, level = level, type = "MC", n.mc = n.mc)
}
