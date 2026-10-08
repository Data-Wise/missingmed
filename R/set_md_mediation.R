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
#' @details
#' The model is validated before anything is fit. Formulas are first expanded
#' against the data, so `Y ~ .` is checked as the model that [run()] fits.
#' `set_md_mediation()` refuses:
#' * a one-sided formula, or a `treatment`/`mediator` that is not a single
#'   variable name;
#' * a variable in either formula that is neither a column of the data nor
#'   defined in the formula's environment (the treatment and mediator must be
#'   columns);
#' * a `formula_m` whose response is not the bare `mediator` column (a
#'   transform such as `log(M)` needs its own column), or a `formula_y` whose
#'   response involves the mediator;
#' * a `treatment` that is not a main effect of `formula_m` and of
#'   `formula_y`, or a `mediator` that is not a main effect of `formula_y`;
#' * any other term involving the treatment or mediator. Both enter only as
#'   main effects, plus, in `formula_y` only, one treatment-by-mediator
#'   interaction (`X:M`, `M:X` or from `X * M`). Products such as `X:C`,
#'   `M:W` or `X:M:W`, transforms such as `I(X^2)`, `poly(X, 2)` or `log(M)`,
#'   and offsets involving either variable are refused. For moderated models,
#'   [mbco_d4()] tests the indirect effect on the completed datasets;
#' * an `X:M` term when `family_y` or `family_m` is not Gaussian with an
#'   identity link;
#' * a treatment column that is not numeric. Factor, character and logical
#'   treatments must be recoded to numeric (0/1 for a binary treatment).
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

  .check_md_spec(formula_y, formula_m, treatment, mediator,
    family_y, family_m, original_data)

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

# Role checks shared by set_md_mediation() and mbco_d4(): two-sided formulas,
# single-name roles, the treatment predicts the mediator, the mediator predicts
# the outcome, the response of `formula_m` is the mediator and the mediator is
# not the outcome. They work on variables (all.vars()), not terms, so
# mbco_d4() keeps accepting `log(M) ~ X` and moderated models; the term-level
# rules live in .check_md_spec().
.check_roles <- function(formula_y, formula_m, treatment, mediator) {
  fs <- list(formula_y = formula_y, formula_m = formula_m)
  for (nm in names(fs)) {
    if (!inherits(fs[[nm]], "formula") || length(fs[[nm]]) != 3L) {
      stop("`", nm, "` must be a two-sided formula.", call. = FALSE)
    }
  }
  roles <- list(treatment = treatment, mediator = mediator)
  for (nm in names(roles)) {
    v <- roles[[nm]]
    if (!is.character(v) || length(v) != 1L || is.na(v)) {
      stop("`", nm, "` must be a single variable name.", call. = FALSE)
    }
  }
  if (!treatment %in% all.vars(formula_m[[3]])) {
    stop("`treatment` '", treatment, "' is not a predictor in `formula_m`.",
      call. = FALSE
    )
  }
  if (!mediator %in% all.vars(formula_y[[3]])) {
    stop("`mediator` '", mediator, "' is not a predictor in `formula_y`.",
      call. = FALSE
    )
  }
  # A `formula_m` modelling another variable fits, but its "a path" is the
  # treatment's effect on that variable, so the indirect effect is silently
  # wrong.
  if (!identical(all.vars(formula_m[[2]]), mediator)) {
    stop("The response of `formula_m` is '", deparse1(formula_m[[2]]),
      "', but `mediator` is '", mediator, "'. `formula_m` must model the ",
      "mediator.",
      call. = FALSE
    )
  }
  if (mediator %in% all.vars(formula_y[[2]])) {
    stop("`mediator` '", mediator, "' is the response of `formula_y`; ",
      "`formula_y` must model the outcome.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# Pre-fit validation for set_md_mediation(): .check_roles() plus the term
# grammar run() -> pool() -> infer() can estimate. Formulas are expanded
# against `data` first, so `Y ~ .` is checked as the model that will be fit.
.check_md_spec <- function(formula_y, formula_m, treatment, mediator,
                           family_y, family_m, data) {
  expand <- function(f) stats::formula(stats::terms(f, data = data))
  fy <- expand(formula_y)
  fm <- expand(formula_m)
  .check_roles(fy, fm, treatment, mediator)

  # A name absent from the data is fine if the formula's environment supplies
  # it (a constant such as `k` in `I(C * k)`), as model.frame() would find it;
  # the treatment and mediator must be columns.
  in_env <- function(vs, f) {
    env <- environment(f) %||% globalenv()
    vs[!vapply(vs, exists, logical(1), envir = env)]
  }
  absent <- unique(c(
    in_env(setdiff(all.vars(fy), names(data)), formula_y),
    in_env(setdiff(all.vars(fm), names(data)), formula_m),
    setdiff(c(treatment, mediator), names(data))
  ))
  if (length(absent)) {
    stop("Variable", if (length(absent) > 1L) "s" else "", " ",
      paste0("'", absent, "'", collapse = ", "), " not found in `data`.",
      call. = FALSE
    )
  }

  if (!identical(fm[[2]], as.name(mediator))) {
    stop("The response of `formula_m` must be the mediator column '", mediator,
      "' itself, not '", deparse1(fm[[2]]), "'. Create a transformed column ",
      "in the data and use it as `mediator` in both formulas.",
      call. = FALSE
    )
  }

  is_role <- function(s, v) identical(str2lang(s), as.name(v))
  tt <- list(formula_y = stats::terms(fy), formula_m = stats::terms(fm))
  need <- list(
    c("formula_y", treatment, "treatment"),
    c("formula_y", mediator, "mediator"),
    c("formula_m", treatment, "treatment")
  )
  for (nd in need) {
    labs <- attr(tt[[nd[1]]], "term.labels")
    if (!any(vapply(labs, is_role, logical(1), v = nd[2]))) {
      stop("`", nd[3], "` '", nd[2], "' must enter `", nd[1], "` as a main ",
        "effect.",
        call. = FALSE
      )
    }
  }

  # Term grammar: the treatment and mediator enter only as bare main effects,
  # plus, in `formula_y`, the one treatment-by-mediator product. Any other term
  # carrying them (X:C, M:W, X:M:W, I(X^2), poly(X, 2), log(M)) changes what
  # the a, b and c' coefficients mean, and the pipeline would pool them as if
  # it did not.
  roles <- c(treatment, mediator)
  has_xm <- FALSE
  for (nm in names(tt)) {
    t_nm <- tt[[nm]]
    labs <- attr(t_nm, "term.labels")
    fac <- attr(t_nm, "factors")
    for (j in seq_along(labs)) {
      if (!any(roles %in% all.vars(str2lang(labs[j])))) next
      if (is_role(labs[j], treatment) || is_role(labs[j], mediator)) next
      comps <- rownames(fac)[fac[, j] > 0]
      xm <- nm == "formula_y" && length(comps) == 2L &&
        ((is_role(comps[1], treatment) && is_role(comps[2], mediator)) ||
          (is_role(comps[1], mediator) && is_role(comps[2], treatment)))
      if (xm) {
        has_xm <- TRUE
        next
      }
      stop("Term `", labs[j], "` in `", nm, "` is not supported: the ",
        "treatment and mediator may enter only as main effects, plus one ",
        "treatment-by-mediator interaction (`", treatment, ":", mediator,
        "`) in `formula_y`. For moderated or transformed paths, test the ",
        "indirect effect with mbco_d4() on the completed datasets.",
        call. = FALSE
      )
    }
    off <- attr(t_nm, "offset")
    vars <- as.list(attr(t_nm, "variables"))[-1L]
    for (o in off) {
      if (any(roles %in% all.vars(vars[[o]]))) {
        stop("Offset `", deparse1(vars[[o]]), "` in `", nm, "` involves the ",
          "treatment or mediator, which set_md_mediation() does not support.",
          call. = FALSE
        )
      }
    }
  }

  # The X:M effect a(b + theta3 x) is a product of linear-model coefficients;
  # on a nonlinear link it is not the indirect effect.
  if (has_xm) {
    fams <- list(family_y = family_y, family_m = family_m)
    for (nm in names(fams)) {
      f <- fams[[nm]]
      if (is.character(f)) f <- get(f, mode = "function", envir = parent.frame())
      if (is.function(f)) f <- f()
      ok <- inherits(f, "family") && identical(f$family, "gaussian") &&
        identical(f$link, "identity")
      if (!ok) {
        stop("A treatment-by-mediator interaction (`", treatment, ":",
          mediator, "`) in `formula_y` needs Gaussian models with an identity ",
          "link; `", nm, "` is not. Drop the interaction or use Gaussian ",
          "`family_y` and `family_m`.",
          call. = FALSE
        )
      }
    }
  }

  x <- data[[treatment]]
  if (!is.numeric(x)) {
    stop("`treatment` '", treatment, "' must be a numeric column (0/1 for a ",
      "binary treatment, or continuous), not ", class(x)[1L], ". Recode it to ",
      "numeric before calling set_md_mediation().",
      call. = FALSE
    )
  }
  invisible(TRUE)
}
