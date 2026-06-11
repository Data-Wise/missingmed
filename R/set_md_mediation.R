#' Set up a mediation analysis with multiply imputed data
#'
#' Constructs an [MDMediationData] object: the entry point of the missingmed S7
#' pipeline. It validates that `data` is a [mice::mids] object and that `model`
#' is a supported mediation model (`lavaan` syntax/object or `OpenMx` `MxModel`),
#' fits the model to the original (listwise-deleted) data, and derives the
#' fitting backend. It is the S7 successor of the S4 [set_sem()] constructor.
#'
#' The estimator (`method`) and the fitting backend (derived `sem_method`) are
#' orthogonal: `method` chooses the missing-data estimator, while the backend is
#' inferred from `model`.
#'
#' @param data A [mice::mids] object containing multiply imputed datasets.
#' @param model A `lavaan` model syntax (character), a fitted `lavaan` object, or
#'   an `OpenMx` `MxModel` (with or without data).
#' @param method Estimator axis: `"mi"` (default, multiple imputation) or
#'   `"ipw"` (inverse-probability weighting; reserved for a later phase).
#' @param mechanism Assumed missing-data mechanism: `"mar"` (default) or `"mnar"`.
#' @param conf_int Logical; whether downstream output carries confidence
#'   intervals. Defaults to `FALSE`.
#' @param conf_level Numeric in (0, 1); confidence level. Defaults to `0.95`.
#'
#' @return An [MDMediationData] object.
#' @seealso [MDMediationData], [run()], [pool()], [infer()], [set_sem()]
#' @examples
#' \dontrun{
#' data("HolzingerSwineford1939", package = "lavaan")
#' imp <- mice::mice(HolzingerSwineford1939[paste0("x", 1:9)],
#'   m = 3, printFlag = FALSE)
#' model <- "visual =~ x1 + x2 + x3"
#' md <- set_md_mediation(imp, model)
#' }
#' @export
set_md_mediation <- function(data, model,
                             method = c("mi", "ipw"),
                             mechanism = c("mar", "mnar"),
                             conf_int = FALSE,
                             conf_level = 0.95) {
  if (missing(data)) stop("Argument 'data' is missing.", call. = FALSE)
  if (missing(model)) stop("Argument 'model' is missing.", call. = FALSE)
  method <- match.arg(method)
  mechanism <- match.arg(mechanism)

  if (!inherits(data, "mids")) {
    stop("'data' must be a 'mids' object from the 'mice' package.", call. = FALSE)
  }
  if (!all(model_type(model) %in% c("lavaan_syntax", "lavaan", "MxModel", "OpenMx"))) {
    stop("'model' must be lavaan syntax, a lavaan object, or an OpenMx model.",
      call. = FALSE)
  }
  if (!is.logical(conf_int) || length(conf_int) != 1L) {
    stop("'conf_int' must be a single logical value.", call. = FALSE)
  }
  if (conf_int && (!is.numeric(conf_level) || length(conf_level) != 1L ||
    conf_level <= 0 || conf_level >= 1)) {
    stop("'conf_level' must be a single number in (0, 1).", call. = FALSE)
  }

  n_imputations <- n_imp(data)
  original_data <- mice::complete(data, action = 0L)
  fit_model0 <- fit_model(model, original_data)
  sem_method <- model_type(fit_model0)
  sem_method <- ifelse(all(sem_method %in% c("MxModel", "OpenMx")), "OpenMx", "lavaan")

  MDMediationData(
    data = data,
    model = model,
    method = method,
    mechanism = mechanism,
    sem_method = sem_method,
    conf_int = conf_int,
    conf_level = conf_level,
    original_data = original_data,
    n_imputations = n_imputations,
    fit_model = fit_model0
  )
}
