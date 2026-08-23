#' Set up a mediation analysis with missing data (MI or IPW)
#'
#' Constructs an [MDMediationData] object: the entry point of the missingmed S7
#' pipeline. It records a **medfit-style mediation specification** (outcome and
#' mediator formulas plus the treatment/mediator roles) together with the data.
#' Fitting is delegated to [medfit::fit_mediation()] downstream by [run()]. It is
#' the S7 successor of the S4 [set_sem()] constructor.
#'
#' Two estimators share the interface (`method`):
#' * `"mi"` — `data` is a [mice::mids] object; [run()] fits every imputation.
#' * `"ipw"` — `data` is a raw `data.frame`; [run()] reweights the complete cases
#'   by inverse missingness probability and fits once.
#'
#' @param data For `method = "mi"`, a [mice::mids] object; for `method = "ipw"`,
#'   a `data.frame` (may contain `NA`s; complete cases are reweighted).
#' @param formula_y Outcome model formula (e.g. `Y ~ X + M + C`).
#' @param formula_m Mediator model formula (e.g. `M ~ X + C`).
#' @param treatment Name of the treatment/exposure variable.
#' @param mediator Name of the mediator variable.
#' @param engine medfit fitting engine. Defaults to `"glm"`.
#' @param family_y,family_m `stats::family` objects for the outcome and mediator
#'   models. Default `stats::gaussian()`.
#' @param method Estimator axis: `"mi"` (default) or `"ipw"`.
#' @param mechanism **Deprecated.** The pipeline estimates under MAR regardless,
#'   so this argument never changed behavior. Passing `"mnar"` warns and is
#'   ignored. Use [sensitivity_mnar()] to assess departures from MAR; it sets
#'   `mechanism = "mnar"` on the objects it creates.
#' @param weight_formula (IPW) Missingness model: `NULL` (default; all observed
#'   predictors), a single `formula`, or a named `list` of per-variable formulas.
#' @param weight_stabilize (IPW) Use stabilized weights? Default `TRUE`.
#' @param weight_trim (IPW) Upper quantile to cap weights; `1` (default) = none.
#' @param se_type (IPW) `"sandwich"` (default, HC robust) or `"model"`.
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
#' # MI
#' imp <- mice::mice(d, m = 5, printFlag = FALSE)
#' md_mi <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
#'   treatment = "X", mediator = "M")
#' # IPW (raw data.frame)
#' md_ipw <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
#'   treatment = "X", mediator = "M", method = "ipw")
#' }
#' @export
set_md_mediation <- function(data, formula_y, formula_m,
                             treatment, mediator,
                             engine = "glm",
                             family_y = stats::gaussian(),
                             family_m = stats::gaussian(),
                             method = c("mi", "ipw"),
                             mechanism = c("mar", "mnar"),
                             weight_formula = NULL,
                             weight_stabilize = TRUE,
                             weight_trim = 1,
                             se_type = c("sandwich", "model"),
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
  # D1: `mechanism` is derived, not user-set. The pipeline estimates under MAR
  # regardless of what is passed here, so accepting "mnar" silently would imply
  # an estimator change that does not happen. Only sensitivity_mnar() stamps it.
  if (!missing(mechanism) && identical(match.arg(mechanism), "mnar")) {
    warning(
      "`mechanism = \"mnar\"` is deprecated and has no effect: run() estimates ",
      "under MAR either way. Use sensitivity_mnar() to assess departures from ",
      "MAR; it stamps mechanism = \"mnar\" on the objects it produces.",
      call. = FALSE
    )
  }
  mechanism <- "mar"
  se_type <- match.arg(se_type)

  if (method == "mi" && !inherits(data, "mids")) {
    stop("'data' must be a 'mids' object when method = 'mi'.", call. = FALSE)
  }
  if (method == "ipw" && !is.data.frame(data)) {
    stop("'data' must be a data.frame when method = 'ipw'.", call. = FALSE)
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

  if (method == "mi") {
    n_imputations <- n_imp(data)
    original_data <- mice::complete(data, action = 0L)
  } else {
    n_imputations <- 1
    original_data <- as.data.frame(data)
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
    weight_formula = weight_formula,
    weight_stabilize = weight_stabilize,
    weight_trim = weight_trim,
    se_type = se_type,
    conf_int = conf_int,
    conf_level = conf_level,
    n_imputations = n_imputations,
    original_data = original_data
  )
}
