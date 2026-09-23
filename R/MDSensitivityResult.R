#' MDSensitivityResult: MNAR sensitivity curve (S7)
#'
#' An S7 class holding the result of [sensitivity_mnar()]: one inference result
#' per rung of a delta grid, plus the grid itself and the realized marginal
#' sensitivity parameters.
#'
#' @section The delta scale:
#' `@grid` holds **conditional** sensitivity parameters (CSPs) -- the values the
#' user supplied. `@msp` holds the **marginal** sensitivity parameter actually
#' realized at each rung: the mean difference between imputed and observed values
#' of the target. They are not the same quantity and can differ substantially;
#' see `vignette("technical")` and [sensitivity_mnar()].
#'
#' @param rungs List of inference results, one per row of `grid`.
#' @param grid Data frame of delta values; one column per target, one row per rung.
#' @param msp Numeric vector of realized marginal sensitivity parameters, one per
#'   rung, computed on the first target (`target[1]`).
#' @param target Character; the shifted variable(s).
#' @param type Inference type used for each rung (`"mc"` or `"mbco"`).
#' @param level Numeric in (0, 1); the confidence level the rungs were built
#'   at. Needed by `summary()` to decide whether an `"mbco"` rung retains the
#'   null, since that test reports a p-value rather than an interval.
#' @param seed Integer seed pinned across rungs.
#' @param seed_source `"mids"` if taken from the supplied `mids`, `"argument"` if
#'   passed explicitly, `"default"` if neither was available.
#' @param method_target The `mice` imputation method(s) used for the target variable(s).
#' @param mechanism_used How the delta was applied, one entry per target:
#'   `"post"` (drawn values shifted), `"mnar.norm"` or `"mnar.logreg"` (mice's
#'   NARFCS methods).
#' @param scale The delta scale, one entry per target: `"raw"` (units of the
#'   target) or `"logodds"` (the `mnar.logreg` route).
#' @param source The originating [MDMediationData].
#'
#' @return An `MDSensitivityResult` S7 object.
#' @seealso [sensitivity_mnar()]
#' @export
#' @name MDSensitivityResult
MDSensitivityResult <- S7::new_class(
  "MDSensitivityResult",
  package = "missingmed",
  properties = list(
    rungs = S7::class_list,
    grid = S7::new_property(S7::class_data.frame, default = quote(data.frame())),
    msp = S7::new_property(S7::class_numeric, default = quote(numeric())),
    target = S7::class_character,
    type = S7::new_property(S7::class_character, default = "mc"),
    level = S7::new_property(S7::class_numeric, default = 0.95),
    seed = S7::class_numeric,
    seed_source = S7::new_property(S7::class_character, default = "argument"),
    method_target = S7::new_property(S7::class_character, default = NA_character_),
    mechanism_used = S7::new_property(S7::class_character, default = NA_character_),
    scale = S7::new_property(S7::class_character, default = NA_character_),
    source = S7::class_any
  ),
  validator = function(self) {
    if (nrow(self@grid) != length(self@rungs)) {
      return("@grid must have one row per element of @rungs.")
    }
    if (length(self@msp) && length(self@msp) != length(self@rungs)) {
      return("@msp must be empty or have one value per rung.")
    }
    if (length(self@type) != 1L || !self@type %in% c("mc", "mbco")) {
      return("@type must be a single string: 'mc' or 'mbco'.")
    }
    if (!all(is.na(self@mechanism_used) |
      self@mechanism_used %in% c("post", "mnar.norm", "mnar.logreg"))) {
      return("@mechanism_used entries must be 'post', 'mnar.norm' or 'mnar.logreg'.")
    }
    if (!all(is.na(self@scale) | self@scale %in% c("raw", "logodds"))) {
      return("@scale entries must be 'raw' or 'logodds'.")
    }
    NULL
  }
)

S7::S4_register(MDSensitivityResult)
