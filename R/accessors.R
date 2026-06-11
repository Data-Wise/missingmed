#' Access the per-imputation mediation fits (for MBCO)
#'
#' Returns the list of per-imputation **named** [medfit::MediationData] objects
#' held in an [MDMediationFit], together with the number of imputations `m`.
#'
#' This accessor exists because **MBCO does not commute with Rubin's rules**:
#' D4-stacked MBCO needs the per-imputation fits, not the pooled estimate. The
#' list it returns is the shape consumed by [infer()]`(type = "mbco")` and by an
#' external [RMediation::mbco()] MI entry point (missingmed issue #2).
#'
#' @param object An [MDMediationFit] object.
#' @return A list with components `per_imputation` (a length-`m` list of named
#'   [medfit::MediationData]) and `m` (the number of imputations).
#' @seealso [run()], [infer()]
#' @export
#' @name per_imputation_list
per_imputation_list <- S7::new_generic("per_imputation_list", "object")

S7::method(per_imputation_list, MDMediationFit) <- function(object) {
  list(per_imputation = object@per_imputation, m = object@m)
}

#' Number of imputations
#'
#' @param object An [MDMediationFit] or [MDMediationResult] object.
#' @return Integer count of imputations.
#' @export
#' @name n_imputations
n_imputations <- S7::new_generic("n_imputations", "object")

S7::method(n_imputations, MDMediationFit) <- function(object) object@m
S7::method(n_imputations, MDMediationResult) <- function(object) object@m
