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
#' It is the S7 successor of the S4 [run_sem()] method.
#'
#' @param object An [MDMediationData] object.
#' @param ... Additional arguments forwarded to [medfit::fit_mediation()].
#' @return An [MDMediationFit] object.
#' @seealso [set_md_mediation()], [pool()], [infer()], [run_sem()]
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
  per_imp <- vector("list", m)
  warns <- vector("list", m)
  # If a fit fails, the warnings of the fits before it are still raised.
  withCallingHandlers(
    for (i in seq_len(m)) {
      r <- .md_fit_one(object, implist[[i]], sprintf("imputation %d of %d", i, m), ...)
      per_imp[[i]] <- r$fit
      warns[[i]] <- r$warnings
    },
    error = function(e) .md_warn_fits(warns, object@engine, m)
  )
  .md_warn_fits(warns, object@engine, m)
  names(per_imp) <- names(implist)

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

# A model variable that mice left unimputed (method "") is still incomplete in
# every completed dataset, and the engine then fits each one on its complete
# cases while @n_obs (and the complete-data df) still counts every row.
.warn_unimputed <- function(object, implist) {
  vars <- intersect(
    unique(c(all.vars(object@formula_y), all.vars(object@formula_m))),
    names(implist[[1]])
  )
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
# no case weights, so the IPW path is glm-only.
.md_engines <- function(method = "mi") {
  if (identical(method, "ipw")) {
    return("glm")
  }
  if (.medfit_version() >= "0.4.0") c("glm", "regmedint") else "glm"
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
  } else if (identical(engine, "lavaan")) {
    paste0(" A lavaan engine is planned for missingmed 0.6.0; until then, the ",
      "deprecated set_sem() fits lavaan models.")
  } else {
    ""
  }
  stop("`engine` \"", engine, "\" is not supported",
    if (identical(method, "ipw")) " with method = \"ipw\"", ". Supported: ",
    paste0("\"", ok, "\"", collapse = ", "), ".", hint,
    call. = FALSE
  )
}

# The one call into medfit. Kept apart from .md_fit_one() so a test can
# replace the engine and still exercise the error and warning handling.
.md_engine_call <- function(object, data, ...) {
  fit_mediation(
    formula_y = object@formula_y,
    formula_m = object@formula_m,
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
