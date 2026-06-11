#' MDMediationResult: pooled mediation result (S7)
#'
#' An S7 class holding the Rubin's-rules pooled mediation result. Its defining
#' feature is `pooled`: a single **named** [medfit::MediationData] built from the
#' pooled estimates and total variance-covariance, valid as input to
#' [RMediation::ci_mediation_data()] / [RMediation::medci()] (path coefficients
#' resolve by name). It is the S7 successor of the S4 [PooledSEMResults] class.
#'
#' @param pooled A named [medfit::MediationData] carrying the pooled estimates
#'   and total vcov (path labels `a`, `b`, `c_prime`, ...).
#' @param tidy_table A data frame of pooled estimates (term, estimate, std_error,
#'   p_value, var_w, var_b, var_tot).
#' @param cov_total,cov_between,cov_within The Rubin's-rules total, between-, and
#'   within-imputation covariance matrices.
#' @param m Integer number of imputations pooled.
#' @param sem_method Fitting backend: `"lavaan"` or `"OpenMx"`.
#' @param conf_int Logical; whether the tidy table carries confidence intervals.
#' @param conf_level Numeric in (0, 1); confidence level.
#'
#' @return An `MDMediationResult` S7 object.
#' @seealso [pool()], [infer()], [PooledSEMResults]
#' @export
#' @name MDMediationResult
MDMediationResult <- S7::new_class(
  "MDMediationResult",
  package = "missingmed",
  properties = list(
    pooled = S7::class_any,
    tidy_table = S7::class_data.frame,
    cov_total = S7::class_any,
    cov_between = S7::class_any,
    cov_within = S7::class_any,
    m = S7::class_numeric,
    sem_method = S7::new_property(S7::class_character, default = "lavaan"),
    conf_int = S7::new_property(S7::class_logical, default = FALSE),
    conf_level = S7::new_property(S7::class_numeric, default = 0.95)
  ),
  validator = function(self) {
    if (length(self@m) != 1L || self@m < 1) {
      return("@m must be a single positive number of imputations.")
    }
    NULL
  }
)
