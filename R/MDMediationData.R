#' MDMediationData: imputed data + mediation model (S7)
#'
#' An S7 class holding multiply imputed data together with a mediation model
#' specification. It is the entry point of the missingmed S7 pipeline
#' (`set_md_mediation()` -> [run()] -> [pool()] -> [infer()]) and the S7
#' successor of the S4 [SemImputedData] class.
#'
#' The estimator and the model are kept as **orthogonal axes**: `method`
#' selects the missing-data estimator (`"mi"` multiple imputation, `"ipw"`
#' inverse-probability weighting), while `sem_method` (derived from `model`)
#' selects the fitting backend (`"lavaan"` or `"OpenMx"`).
#'
#' @param data An object of class `mids` from the `mice` package.
#' @param model A `lavaan` model syntax (character), a fitted `lavaan` object,
#'   or an `OpenMx` `MxModel`.
#' @param method Estimator axis: `"mi"` (default) or `"ipw"`.
#' @param mechanism Assumed missing-data mechanism: `"mar"` (default) or `"mnar"`.
#' @param sem_method Derived fitting backend: `"lavaan"` or `"OpenMx"`.
#' @param conf_int Logical; whether downstream output carries confidence
#'   intervals. Defaults to `FALSE`.
#' @param conf_level Numeric in (0, 1); confidence level. Defaults to `0.95`.
#' @param original_data The original (pre-imputation) data, derived from `data`.
#' @param n_imputations Number of imputations, derived from `data`.
#' @param fit_model The model fitted to the original data with listwise deletion.
#'
#' @return An `MDMediationData` S7 object.
#' @seealso [set_md_mediation()], [SemImputedData]
#' @export
#' @name MDMediationData
MDMediationData <- S7::new_class(
  "MDMediationData",
  package = "missingmed",
  properties = list(
    data = S7::class_any,
    model = S7::class_any,
    method = S7::new_property(S7::class_character, default = "mi"),
    mechanism = S7::new_property(S7::class_character, default = "mar"),
    sem_method = S7::new_property(S7::class_character, default = "lavaan"),
    conf_int = S7::new_property(S7::class_logical, default = FALSE),
    conf_level = S7::new_property(S7::class_numeric, default = 0.95),
    original_data = S7::class_data.frame,
    n_imputations = S7::class_numeric,
    fit_model = S7::class_any
  ),
  validator = function(self) {
    if (!inherits(self@data, "mids")) {
      return("@data must be a 'mids' object from the 'mice' package.")
    }
    if (length(self@method) != 1L || !self@method %in% c("mi", "ipw")) {
      return("@method must be a single string: 'mi' or 'ipw'.")
    }
    if (length(self@mechanism) != 1L || !self@mechanism %in% c("mar", "mnar")) {
      return("@mechanism must be a single string: 'mar' or 'mnar'.")
    }
    if (length(self@conf_int) != 1L) {
      return("@conf_int must be a single logical value.")
    }
    if (length(self@conf_level) != 1L || self@conf_level <= 0 || self@conf_level >= 1) {
      return("@conf_level must be a single number in (0, 1).")
    }
    NULL
  }
)
