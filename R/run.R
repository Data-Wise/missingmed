#' Fit the mediation model across imputations
#'
#' Runs the mediation specification held in an [MDMediationData] object on every
#' imputed dataset, delegating each fit to [medfit::fit_mediation()]. The result
#' is an [MDMediationFit] whose `per_imputation` slot is a list of **named**
#' [medfit::MediationData] objects (one per imputation) — the shape consumed by
#' both Rubin's-rules pooling ([pool()]) and D4-stacked MBCO ([infer()]).
#'
#' It is the S7 successor of the S4 [run_sem()] method.
#'
#' @param object An [MDMediationData] object.
#' @param ... Additional arguments forwarded to [medfit::fit_mediation()].
#' @return An [MDMediationFit] object.
#' @seealso [set_md_mediation()], [pool()], [infer()], [run_sem()]
#' @export
#' @name run
run <- S7::new_generic("run", "object")

S7::method(run, MDMediationData) <- function(object, ...) {
  implist <- mice::complete(object@data, action = "all")

  per_imp <- lapply(implist, function(d) {
    medfit::fit_mediation(
      formula_y = object@formula_y,
      formula_m = object@formula_m,
      data = d,
      treatment = object@treatment,
      mediator = object@mediator,
      engine = object@engine,
      family_y = object@family_y,
      family_m = object@family_m,
      ...
    )
  })

  MDMediationFit(
    per_imputation = per_imp,
    fits = list(),
    m = length(per_imp),
    engine = object@engine,
    conf_int = object@conf_int,
    conf_level = object@conf_level,
    source = object
  )
}
