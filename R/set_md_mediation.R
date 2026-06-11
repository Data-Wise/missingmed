#' Set up a mediation analysis with multiply imputed data
#'
#' Constructs an [MDMediationData] object: the entry point of the missingmed S7
#' pipeline. It records a **medfit-style mediation specification** (outcome and
#' mediator formulas plus the treatment/mediator roles) together with the `mids`
#' object. Fitting is delegated to [medfit::fit_mediation()] downstream by
#' [run()]. It is the S7 successor of the S4 [set_sem()] constructor.
#'
#' @param data A [mice::mids] object containing multiply imputed datasets.
#' @param formula_y Outcome model formula (e.g. `Y ~ X + M + C`).
#' @param formula_m Mediator model formula (e.g. `M ~ X + C`).
#' @param treatment Name of the treatment/exposure variable.
#' @param mediator Name of the mediator variable.
#' @param engine medfit fitting engine. Defaults to `"glm"`.
#' @param family_y,family_m `stats::family` objects for the outcome and mediator
#'   models. Default `stats::gaussian()`.
#' @param method Estimator axis: `"mi"` (default) or `"ipw"` (reserved).
#' @param mechanism Assumed missing-data mechanism: `"mar"` (default) or `"mnar"`.
#' @param conf_int Logical; whether downstream output carries confidence
#'   intervals. Defaults to `FALSE`.
#' @param conf_level Numeric in (0, 1); confidence level. Defaults to `0.95`.
#'
#' @return An [MDMediationData] object.
#' @seealso [MDMediationData], [run()], [pool()], [infer()], [medfit::fit_mediation()]
#' @examples
#' \dontrun{
#' set.seed(1)
#' d <- data.frame(X = rbinom(200, 1, .5), C = rnorm(200))
#' d$M <- .5 * d$X + .3 * d$C + rnorm(200)
#' d$Y <- .2 * d$X + .4 * d$M + .3 * d$C + rnorm(200)
#' d$M[sample(200, 30)] <- NA
#' imp <- mice::mice(d, m = 5, printFlag = FALSE)
#' md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
#'   treatment = "X", mediator = "M")
#' }
#' @export
set_md_mediation <- function(data, formula_y, formula_m,
                             treatment, mediator,
                             engine = "glm",
                             family_y = stats::gaussian(),
                             family_m = stats::gaussian(),
                             method = c("mi", "ipw"),
                             mechanism = c("mar", "mnar"),
                             conf_int = FALSE,
                             conf_level = 0.95) {
  if (missing(data)) stop("Argument 'data' is missing.", call. = FALSE)
  if (missing(formula_y) || missing(formula_m)) {
    stop("Both 'formula_y' and 'formula_m' must be supplied.", call. = FALSE)
  }
  if (missing(treatment) || missing(mediator)) {
    stop("Both 'treatment' and 'mediator' must be supplied.", call. = FALSE)
  }
  method <- match.arg(method)
  mechanism <- match.arg(mechanism)

  if (!inherits(data, "mids")) {
    stop("'data' must be a 'mids' object from the 'mice' package.", call. = FALSE)
  }
  if (!inherits(formula_y, "formula") || !inherits(formula_m, "formula")) {
    stop("'formula_y' and 'formula_m' must be formula objects.", call. = FALSE)
  }
  if (!is.logical(conf_int) || length(conf_int) != 1L) {
    stop("'conf_int' must be a single logical value.", call. = FALSE)
  }
  if (conf_int && (!is.numeric(conf_level) || length(conf_level) != 1L ||
    conf_level <= 0 || conf_level >= 1)) {
    stop("'conf_level' must be a single number in (0, 1).", call. = FALSE)
  }

  MDMediationData(
    data = data,
    formula_y = formula_y,
    formula_m = formula_m,
    treatment = treatment,
    mediator = mediator,
    engine = engine,
    family_y = family_y,
    family_m = family_m,
    method = method,
    mechanism = mechanism,
    conf_int = conf_int,
    conf_level = conf_level,
    n_imputations = n_imp(data),
    original_data = mice::complete(data, action = 0L)
  )
}
