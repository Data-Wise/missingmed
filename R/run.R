#' Fit the mediation model across imputations
#'
#' Runs the mediation specification held in an [MDMediationData] object on every
#' imputed dataset, delegating each fit to [medfit::fit_mediation()]. The result
#' is an [MDMediationFit] whose `per_imputation` slot is a list of **named**
#' [medfit::MediationData] objects (one per imputation) — the shape consumed by
#' both Rubin's-rules pooling ([pool()]) and D4-stacked MBCO ([infer()]).
#'
#' An engine error is rethrown with the engine and the imputation it failed
#' on. Engine warnings (a `glm` that did not converge, fitted probabilities of
#' 0 or 1) are collected and raised once, naming the imputations that produced
#' them.
#'
#' It is the S7 successor of the S4 `run_sem()` method.
#'
#' @param object An [MDMediationData] object.
#' @param ... `r lifecycle::badge("deprecated")` Additional arguments forwarded to
#'   [medfit::fit_mediation()]; set them with `fit_args` in
#'   [set_md_mediation()] instead. They are still honored, with a warning, and
#'   may not repeat a name already in `fit_args`.
#' @return An [MDMediationFit] object.
#' @seealso [set_md_mediation()], [pool()], [infer()]
#' @examples
#' set.seed(1)
#' n <- 150
#' d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
#' d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
#' d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
#' d$M[sample(n, 25)] <- NA
#' imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
#' md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
#'   treatment = "X", mediator = "M"
#' )
#' fit <- run(md)
#' fit
#' @importFrom medfit fit_mediation
#' @export
#' @name run
run <- S7::new_generic("run", "object")

S7::method(run, MDMediationData) <- function(object, ...) {
  # IPW: reweight the complete cases and fit once (see .ipw_run).
  if (object@method == "ipw") {
    return(.ipw_run(object, ...))
  }
  # MDMediationData() can be built without set_md_mediation(), so the engine
  # is checked here as well.
  .check_engine(object@engine, object@method)

  # MI: fit every imputation.
  implist <- mice::complete(object@data, action = "all")
  m <- length(implist)
  .warn_unimputed(object, implist)
  if (identical(object@engine, "lavaan") && ...length() > 0L) {
    stop("`run()` takes no extra arguments for engine = \"lavaan\"; set them ",
      "with `fit_args` in set_md_mediation().",
      call. = FALSE
    )
  }
  extra <- if (identical(object@engine, "lavaan")) list() else {
    .md_extra_args(object, list(...))
  }
  per_imp <- vector("list", m)
  warns <- vector("list", m)
  # If a fit fails, the warnings of the fits before it are still raised.
  withCallingHandlers(
    for (i in seq_len(m)) {
      r <- do.call(.md_fit_one, c(
        list(object, implist[[i]], sprintf("imputation %d of %d", i, m)), extra
      ))
      per_imp[[i]] <- r$fit
      warns[[i]] <- r$warnings
    },
    error = function(e) .md_warn_fits(warns, object@engine, m)
  )
  .md_warn_fits(warns, object@engine, m)
  names(per_imp) <- names(implist)
  .md_refuse_nonconverged(per_imp, object@engine)

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

# The stored formula is the user's (`Y ~ .` stays `Y ~ .`), but medfit cannot
# fit a `.`, so it is expanded against the data set_md_mediation() validated
# it on. Only a dotted formula changes: expanding reorders terms (X * M
# becomes X + M + X:M), and with them the coefficients.
.expand_dot <- function(f, data) {
  if (!"." %in% all.vars(f)) {
    return(f)
  }
  stats::formula(stats::terms(f, data = data))
}

# All variables of both model formulas, with `.` expanded.
.model_vars <- function(object) {
  if (identical(object@engine, "lavaan")) {
    return(lavaan::lavNames(lavaan::lavaanify(object@model), "ov"))
  }
  unique(c(
    all.vars(.expand_dot(object@formula_y, object@original_data)),
    all.vars(.expand_dot(object@formula_m, object@original_data))
  ))
}

# A model variable that mice left unimputed (method "") is still incomplete in
# every completed dataset, and the engine then fits each one on its complete
# cases while @n_obs (and the complete-data df) still counts every row.
.warn_unimputed <- function(object, implist) {
  vars <- intersect(.model_vars(object), names(implist[[1]]))
  incomplete <- vars[vapply(vars, function(v) {
    any(vapply(implist, function(d) anyNA(d[[v]]), logical(1)))
  }, logical(1))]
  if (length(incomplete)) {
    warning("Model variable", if (length(incomplete) > 1L) "s", " ",
      paste0("'", incomplete, "'", collapse = ", "), " still ",
      if (length(incomplete) > 1L) "have" else "has", " missing values ",
      "after imputation (mice method \"\"?), so each imputation is fit on ",
      "its complete cases only. Impute ",
      if (length(incomplete) > 1L) "them" else "it", " in mice().",
      call. = FALSE
    )
  }
  invisible(incomplete)
}

# Engines that run end to end through run() -> pool() -> infer(). The one
# place the supported set is defined. medfit 0.4.0 added "regmedint"; it takes
# no case weights, so the IPW path is glm and lavaan only.
.md_engines <- function(method = "mi") {
  if (identical(method, "ipw")) {
    return(c("glm", "lavaan"))
  }
  # "lavaan" is fit by lavaan::sem() and converted by medfit::extract_mediation(),
  # so it does not depend on the medfit engine list.
  if (.medfit_version() >= "0.4.0") c("glm", "regmedint", "lavaan") else c("glm", "lavaan")
}

.medfit_version <- function() numeric_version(getNamespaceVersion("medfit"))

.check_engine <- function(engine, method = "mi") {
  if (!is.character(engine) || length(engine) != 1L || is.na(engine)) {
    stop("`engine` must be a single string.", call. = FALSE)
  }
  ok <- .md_engines(method)
  if (engine %in% ok) {
    return(invisible(TRUE))
  }
  # The IPW restriction comes first, so its message does not depend on the
  # installed medfit.
  hint <- if (identical(method, "ipw") && identical(engine, "regmedint")) {
    paste0(" engine = \"regmedint\" takes no case weights; use ",
      "engine = \"glm\" with method = \"ipw\".")
  } else if (identical(engine, "regmedint")) {
    paste0(" engine = \"regmedint\" needs medfit >= 0.4.0 (installed: ",
      format(.medfit_version()), ").")
  } else {
    ""
  }
  stop("`engine` \"", engine, "\" is not supported",
    if (identical(method, "ipw")) " with method = \"ipw\"", ". Supported: ",
    paste0("\"", ok, "\"", collapse = ", "), ".", hint,
    call. = FALSE
  )
}

# One lavaan::sem() call, kept apart so a test can replace it.
.lav_sem <- function(model, data, fit_args) {
  do.call(lavaan::sem, c(list(model = model, data = data), fit_args))
}

# A lavaan fit, converted by medfit::extract_mediation(). A fit that did not
# converge returns an "md_nonconverged" marker instead, so run() can refuse once
# naming every such imputation (G2). A converged but improper solution (for
# example a negative residual variance) is a warning: lavaan's own is collected
# by .md_fit_one(), and when lavaan stayed silent one is raised here.
.md_lavaan_call <- function(object, data) {
  n_warn <- 0L
  args <- object@fit_args
  if (identical(object@method, "ipw")) {
    # The IPW path appends its weights as `.md_ipw_w`; robust (sandwich) SEs are
    # forced, as for the glm IPW path (G1).
    args <- args[.lav_key(names(args)) != "se"]
    args <- c(args, list(sampling_weights = ".md_ipw_w", se = "robust.huber.white"))
  }
  fit <- withCallingHandlers(
    .lav_sem(object@model, data, args),
    warning = function(w) n_warn <<- n_warn + 1L
  )
  if (!isTRUE(lavaan::lavInspect(fit, "converged"))) {
    return(structure(list(), class = "md_nonconverged"))
  }
  if (identical(object@method, "ipw")) fit <- .lav_round_nobs(fit)
  if (!isTRUE(lavaan::lavInspect(fit, "post.check")) && n_warn == 0L) {
    warning("improper solution (lavaan's post.check failed).", call. = FALSE)
  }
  medfit::extract_mediation(fit,
    treatment = object@treatment, mediator = object@mediator,
    outcome = object@outcome
  )
}

# lavaan normalizes sampling weights to sum to N with floating-point error, so
# lavInspect(fit, "nobs") reads 355.99999999999994 for N = 356, and
# medfit::extract_mediation() truncates that with as.integer() to 355 and then
# rejects the object (rows of data != n_obs). Rounding the weighted counts
# restores N; the model fit itself is untouched.
# Removable once medfit >= 0.5.1 is on CRAN: medfit PR #85 (released in 0.5.1)
# rounds the count itself. Then raise the medfit floor in DESCRIPTION and delete
# this helper and its call in `.md_lavaan_call()`.
.lav_round_nobs <- function(fit) {
  n <- tryCatch(fit@SampleStats@nobs, error = function(e) NULL)
  if (is.list(n)) fit@SampleStats@nobs <- lapply(n, round)
  fit
}

# Refuse to go on when any imputation's lavaan fit did not converge, naming them.
.md_refuse_nonconverged <- function(per_imp, engine) {
  bad <- which(vapply(per_imp, inherits, logical(1), what = "md_nonconverged"))
  if (length(bad)) {
    stop("engine \"", engine, "\" did not converge on imputation",
      if (length(bad) > 1L) "s", " ", paste(bad, collapse = ", "), " of ",
      length(per_imp), ". Simplify the model, or pass `fit_args` such as ",
      "list(control = list(iter.max = 5000)).",
      call. = FALSE
    )
  }
  invisible(per_imp)
}

# The one call into medfit. Kept apart from .md_fit_one() so a test can
# replace the engine and still exercise the error and warning handling.
.md_engine_call <- function(object, data, ...) {
  if (identical(object@engine, "lavaan")) {
    return(.md_lavaan_call(object, data))
  }
  fit_mediation(
    formula_y = .expand_dot(object@formula_y, object@original_data),
    formula_m = .expand_dot(object@formula_m, object@original_data),
    data = data,
    treatment = object@treatment,
    mediator = object@mediator,
    engine = object@engine,
    family_y = object@family_y,
    family_m = object@family_m,
    ...
  )
}

# One engine fit. An error is rethrown naming the engine and `where`, with the
# original message kept. Warnings are collected and muffled here, to be raised
# once by .md_warn_fits(); messages pass through untouched.
.md_fit_one <- function(object, data, where, ...) {
  warns <- character(0)
  fit <- withCallingHandlers(
    tryCatch(.md_engine_call(object, data, ...), error = function(e) {
      msg <- paste0("engine \"", object@engine, "\" failed on ", where, ": ",
        conditionMessage(e))
      if (length(warns)) {
        msg <- paste0(msg, " (after warning: ",
          paste(unique(warns), collapse = "; "), ")")
      }
      # Keep the original classes, so a handler for them still matches, and
      # the original condition as `engine_error`.
      stop(errorCondition(msg,
        class = setdiff(class(e), c("error", "condition")),
        call = NULL, engine_error = e
      ))
    }),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(fit = fit, warnings = warns)
}

# One warning for all the fits: which ones warned, and the distinct messages.
# `m` is the number of imputations, or NULL for the single IPW fit.
.md_warn_fits <- function(warns, engine, m = NULL) {
  hit <- which(lengths(warns) > 0L)
  if (!length(hit)) {
    return(invisible(NULL))
  }
  where <- if (is.null(m)) {
    "the IPW fit"
  } else {
    paste0("imputation", if (length(hit) > 1L) "s", " ",
      paste(hit, collapse = ", "), " of ", m)
  }
  warning("engine \"", engine, "\" warned on ", where, ": ",
    paste(unique(unlist(warns)), collapse = "; "),
    call. = FALSE
  )
}
