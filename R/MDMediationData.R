#' MDMediationData: imputed data + mediation specification (S7)
#'
#' An S7 class holding multiply imputed data together with a **medfit-style
#' mediation specification** (outcome/mediator formulas + roles). It is the entry
#' point of the missingmed S7 pipeline
#' (`set_md_mediation()` -> [run()] -> [pool()] -> [infer()]) and the S7
#' successor of the removed S4 `SemImputedData` class.
#'
#' Fitting is delegated to [medfit::fit_mediation()] (one call per imputation),
#' so the per-imputation fits carry **named** path coefficients (`a`, `b`,
#' `c_prime`) ready for [RMediation] inference. The estimator (`method`) and the
#' model are orthogonal axes: `method` selects the missing-data estimator
#' (`"mi"`/`"ipw"`); the formulas/engine select the model.
#'
#' @param data For `method = "mi"`, an object of class `mids` from the `mice`
#'   package; for `method = "ipw"`, a raw `data.frame` (the complete cases are
#'   reweighted).
#' @param formula_y Outcome model formula (e.g. `Y ~ X + M + C`).
#' @param formula_m Mediator model formula (e.g. `M ~ X + C`).
#' @param treatment Name of the treatment/exposure variable.
#' @param mediator Name of the mediator variable.
#' @param engine medfit fitting engine, e.g. `"glm"` (default).
#' @param family_y,family_m `stats::family` objects for the outcome and mediator
#'   models. Default `stats::gaussian()`.
#' @param method Estimator axis: `"mi"` (default) or `"ipw"`.
#' @param mechanism Assumed missing-data mechanism: `"mar"` (default) or `"mnar"`.
#' @param weight_formula (IPW) Missingness model specification: `NULL` (default;
#'   use all observed predictors), a single `formula` (joint complete-case
#'   model), or a named `list` of formulas (per-variable models). Ignored for MI.
#' @param weight_stabilize (IPW) Logical; if `TRUE` (default) use stabilized
#'   weights `P(R=1|X) / P(R=1|Z)`. Ignored for MI.
#' @param weight_trim (IPW) Upper quantile at which to cap weights (e.g. `0.99`);
#'   `1` (default) disables trimming. Ignored for MI.
#' @param se_type (IPW) Variance estimator passed to [medfit::fit_mediation()]:
#'   `"sandwich"` (default for IPW, HC robust) or `"model"`. Ignored for MI.
#' @param conf_int Logical; whether downstream output carries confidence
#'   intervals. Defaults to `FALSE`.
#' @param conf_level Numeric in (0, 1); confidence level. Defaults to `0.95`.
#' @param model For `engine = "lavaan"`, the lavaan model syntax (a single
#'   string); `NULL`-equivalent (`character(0)`) otherwise.
#' @param outcome For `engine = "lavaan"`, the name of the outcome variable.
#' @param fit_args For `engine = "lavaan"`, a named list of extra arguments
#'   for [lavaan::sem()]. Empty otherwise.
#' @param n_imputations Number of imputations (MI) or `1` (IPW).
#' @param original_data The original data (pre-imputation for MI; the supplied
#'   frame for IPW).
#'
#' @return An `MDMediationData` S7 object.
#' @seealso [set_md_mediation()], [medfit::fit_mediation()]
#' @export
#' @name MDMediationData
MDMediationData <- S7::new_class(
  "MDMediationData",
  package = "missingmed",
  properties = list(
    data = S7::class_any,
    formula_y = S7::class_any,
    formula_m = S7::class_any,
    treatment = S7::class_character,
    mediator = S7::class_character,
    engine = S7::new_property(S7::class_character, default = "glm"),
    family_y = S7::class_any,
    family_m = S7::class_any,
    method = S7::new_property(S7::class_character, default = "mi"),
    mechanism = S7::new_property(S7::class_character, default = "mar"),
    weight_formula = S7::class_any,
    weight_stabilize = S7::new_property(S7::class_logical, default = TRUE),
    weight_trim = S7::new_property(S7::class_numeric, default = 1),
    se_type = S7::new_property(S7::class_character, default = "sandwich"),
    conf_int = S7::new_property(S7::class_logical, default = FALSE),
    conf_level = S7::new_property(S7::class_numeric, default = 0.95),
    n_imputations = S7::class_numeric,
    model = S7::new_property(S7::class_character, default = character(0)),
    outcome = S7::new_property(S7::class_character, default = character(0)),
    fit_args = S7::new_property(S7::class_list, default = list()),
    original_data = S7::new_property(S7::class_data.frame, default = quote(data.frame()))
  ),
  validator = function(self) {
    if (length(self@method) != 1L || !self@method %in% c("mi", "ipw")) {
      return("@method must be a single string: 'mi' or 'ipw'.")
    }
    if (self@method == "mi" && !inherits(self@data, "mids")) {
      return("@data must be a 'mids' object from the 'mice' package when method = 'mi'.")
    }
    if (self@method == "ipw" && !is.data.frame(self@data)) {
      return("@data must be a data.frame when method = 'ipw'.")
    }
    lav <- identical(self@engine, "lavaan")
    if (lav) {
      # A lavaan model is one syntax string; there are no formulas.
      if (length(self@model) != 1L || is.na(self@model) || !nzchar(self@model)) {
        return("@model must be a single lavaan model syntax string when engine = 'lavaan'.")
      }
      if (length(self@outcome) != 1L || is.na(self@outcome) || !nzchar(self@outcome)) {
        return("@outcome must be a single variable name when engine = 'lavaan'.")
      }
      if (!is.null(self@formula_y) || !is.null(self@formula_m)) {
        return("@formula_y and @formula_m must be NULL when engine = 'lavaan'.")
      }
      if (self@outcome %in% c(self@treatment, self@mediator)) {
        return("@outcome must differ from @treatment and @mediator.")
      }
    } else if (!inherits(self@formula_y, "formula") || !inherits(self@formula_m, "formula")) {
      return("@formula_y and @formula_m must be formula objects.")
    }
    if (!is.list(self@fit_args) ||
      (length(self@fit_args) && (is.null(names(self@fit_args)) || !all(nzchar(names(self@fit_args)))))) {
      return("@fit_args must be a named list.")
    }
    if (length(self@treatment) != 1L || length(self@mediator) != 1L ||
      is.na(self@treatment) || is.na(self@mediator) ||
      !nzchar(self@treatment) || !nzchar(self@mediator)) {
      return("@treatment and @mediator must each be a single variable name.")
    }
    # A shared name fits without error in run() but is not a mediation model.
    if (self@treatment == self@mediator) {
      return("@treatment and @mediator must name different variables.")
    }
    if (length(self@engine) != 1L || is.na(self@engine) || !nzchar(self@engine)) {
      return("@engine must be a single string naming a medfit engine.")
    }
    if (length(self@mechanism) != 1L || !self@mechanism %in% c("mar", "mnar")) {
      return("@mechanism must be a single string: 'mar' or 'mnar'.")
    }
    if (length(self@weight_trim) != 1L || is.na(self@weight_trim) ||
      self@weight_trim <= 0 || self@weight_trim > 1) {
      return("@weight_trim must be a single number in (0, 1].")
    }
    # run() reads this with isTRUE(), so NA would silently mean "unstabilized".
    if (self@method == "ipw" &&
      (length(self@weight_stabilize) != 1L || is.na(self@weight_stabilize))) {
      return("@weight_stabilize must be TRUE or FALSE.")
    }
    if (length(self@se_type) != 1L || !self@se_type %in% c("model", "sandwich")) {
      return("@se_type must be a single string: 'model' or 'sandwich'.")
    }
    if (length(self@conf_int) != 1L) {
      return("@conf_int must be a single logical value.")
    }
    if (length(self@conf_level) != 1L || is.na(self@conf_level) ||
      self@conf_level <= 0 || self@conf_level >= 1) {
      return("@conf_level must be a single number in (0, 1).")
    }
    # Only print() reads it, so a wrong count would mislabel the object
    # silently. Left empty, it is not checked.
    if (length(self@n_imputations)) {
      m_data <- if (self@method == "mi") self@data$m else 1
      if (length(self@n_imputations) != 1L || is.na(self@n_imputations) ||
        self@n_imputations != m_data) {
        return(paste0(
          "@n_imputations must equal the number of imputations in @data (",
          m_data, ")."
        ))
      }
    }
    NULL
  }
)

# Register with S4 so S7 methods can attach to the package's S4 generics
# (print/summary/show were made S4 by the legacy S4 classes).
S7::S4_register(MDMediationData)
