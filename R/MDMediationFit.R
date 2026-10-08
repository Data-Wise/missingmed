#' MDMediationFit: per-imputation mediation fits (S7)
#'
#' An S7 class holding the result of fitting a mediation model across all
#' imputations. Its defining feature is `per_imputation`: a list of **named**
#' [medfit::MediationData] objects, one per imputation. This list is what the
#' MBCO-MI path consumes, because MBCO does not commute with Rubin's rules
#' (D4-stacked MBCO needs the per-imputation fits, not the pooled estimate).
#'
#' It is the S7 successor of the removed S4 `SemResults` class.
#'
#' @param per_imputation A list of named [medfit::MediationData] objects (length `m`).
#' @param fits A list of the raw backend fits (`lavaan`), one per imputation.
#' @param m Integer number of imputations.
#' @param engine medfit fitting engine used (e.g. `"glm"`).
#' @param conf_int Logical; whether output carries confidence intervals.
#' @param conf_level Numeric in (0, 1); confidence level.
#' @param weights (IPW) Full-length numeric IPW weight vector (`NA` for dropped
#'   rows); `NULL` for MI fits.
#' @param source The originating [MDMediationData] (retained so MBCO can refit
#'   constrained/unconstrained models against the imputed data).
#'
#' @return An `MDMediationFit` S7 object.
#' @seealso [run()], [per_imputation_list()]
#' @export
#' @name MDMediationFit
MDMediationFit <- S7::new_class(
  "MDMediationFit",
  package = "missingmed",
  properties = list(
    per_imputation = S7::class_list,
    fits = S7::class_list,
    m = S7::class_numeric,
    engine = S7::new_property(S7::class_character, default = "glm"),
    conf_int = S7::new_property(S7::class_logical, default = FALSE),
    conf_level = S7::new_property(S7::class_numeric, default = 0.95),
    weights = S7::class_any,
    source = S7::class_any
  ),
  validator = function(self) {
    if (length(self@conf_level) != 1L || is.na(self@conf_level) ||
      self@conf_level <= 0 || self@conf_level >= 1) {
      return("@conf_level must be a single number in (0, 1).")
    }
    if (length(self@m) != 1L || is.na(self@m) || self@m < 1) {
      return("@m must be a single positive number of imputations.")
    }
    if (length(self@per_imputation) != self@m) {
      return("@per_imputation must have length @m (one MediationData per imputation).")
    }
    # print() and pool() read @a_path and @b_path from every element. Checked by
    # property, not class: medfit's InteractionMediationData does not inherit
    # from MediationData.
    if (!all(vapply(self@per_imputation, .is_path_fit, logical(1)))) {
      return("@per_imputation must hold medfit mediation fits (S7 objects with @a_path and @b_path).")
    }
    NULL
  }
)

S7::S4_register(MDMediationFit)

# Is `x` a medfit fit that carries the a and b paths? Shared by the
# MDMediationFit and MDMediationResult validators.
.is_path_fit <- function(x) {
  S7::S7_inherits(x) && all(c("a_path", "b_path") %in% S7::prop_names(x))
}
