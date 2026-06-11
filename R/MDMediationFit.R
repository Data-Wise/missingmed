#' MDMediationFit: per-imputation mediation fits (S7)
#'
#' An S7 class holding the result of fitting a mediation model across all
#' imputations. Its defining feature is `per_imputation`: a list of **named**
#' [medfit::MediationData] objects, one per imputation. This list is what the
#' MBCO-MI path consumes, because MBCO does not commute with Rubin's rules
#' (D4-stacked MBCO needs the per-imputation fits, not the pooled estimate).
#'
#' It is the S7 successor of the S4 [SemResults] class.
#'
#' @param per_imputation A list of named [medfit::MediationData] objects (length `m`).
#' @param fits A list of the raw backend fits (`lavaan`/`OpenMx`), one per imputation.
#' @param m Integer number of imputations.
#' @param engine medfit fitting engine used (e.g. `"glm"`).
#' @param conf_int Logical; whether output carries confidence intervals.
#' @param conf_level Numeric in (0, 1); confidence level.
#' @param source The originating [MDMediationData] (retained so MBCO can refit
#'   constrained/unconstrained models against the imputed data).
#'
#' @return An `MDMediationFit` S7 object.
#' @seealso [run()], [per_imputation_list()], [SemResults]
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
    source = S7::class_any
  ),
  validator = function(self) {
    if (length(self@m) != 1L || self@m < 1) {
      return("@m must be a single positive number of imputations.")
    }
    if (length(self@per_imputation) != self@m) {
      return("@per_imputation must have length @m (one MediationData per imputation).")
    }
    NULL
  }
)
