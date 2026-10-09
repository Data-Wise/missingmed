# Validation for engine = "lavaan" in set_md_mediation() (SPEC-s7-sem-engine,
# Q1/G3). Nothing here fits a model.

# Argument conflicts between the formula (glm) and `model` (lavaan) paths,
# refused before anything else is looked at. `lav` is the already-resolved
# engine flag, so an invalid `engine` is reported by .check_engine() instead.
.check_engine_args <- function(lav, formula_y, formula_m, model, outcome,
                               fit_args) {
  if (lav) {
    if (!is.null(formula_y) || !is.null(formula_m)) {
      stop("`formula_y` and `formula_m` cannot be used with engine = ",
        "\"lavaan\"; give the lavaan syntax in `model`.",
        call. = FALSE
      )
    }
    if (is.null(model)) {
      stop("`model` (lavaan syntax) is required when engine = \"lavaan\".",
        call. = FALSE
      )
    }
    if (is.null(outcome)) {
      stop("`outcome` is required when engine = \"lavaan\": name the ",
        "variable that is regressed on the mediator.",
        call. = FALSE
      )
    }
    return(invisible(TRUE))
  }
  if (!is.null(model)) {
    stop("`model` is only used with engine = \"lavaan\".", call. = FALSE)
  }
  .check_fit_args(fit_args)
  invisible(TRUE)
}

# Arguments that set_md_mediation() or run() already pass to
# medfit::fit_mediation() cannot also come from `fit_args` or run(...).
.md_reserved_args <- c("formula_y", "formula_m", "data", "treatment", "mediator",
                       "engine", "family_y", "family_m")

# `fit_args` for the glm and regmedint engines: a named list forwarded to
# medfit::fit_mediation(); it cannot restate what set_md_mediation() sets.
.check_fit_args <- function(fit_args, reserved = .md_reserved_args) {
  if (!is.list(fit_args)) {
    stop("`fit_args` must be a list.", call. = FALSE)
  }
  if (!length(fit_args)) {
    return(invisible(TRUE))
  }
  if (is.null(names(fit_args)) || !all(nzchar(names(fit_args)))) {
    stop("`fit_args` must be a named list.", call. = FALSE)
  }
  bad <- intersect(names(fit_args), reserved)
  if (length(bad)) {
    stop("`fit_args` cannot set ", paste0("`", bad, "`", collapse = ", "),
      "; set_md_mediation() passes ",
      if (length(bad) > 1L) "them" else "it", " itself.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# `outcome` on the glm engines is optional: it is the response of `formula_y`,
# and is checked against it when given.
.check_glm_outcome <- function(outcome, formula_y) {
  if (is.null(outcome)) {
    return(invisible(TRUE))
  }
  resp <- all.vars(formula_y[[2L]])
  if (!is.character(outcome) || length(outcome) != 1L || is.na(outcome) ||
    !identical(outcome, resp[1L]) || length(resp) != 1L) {
    stop("`outcome` is '", paste(outcome, collapse = ", "),
      "' but the response of `formula_y` is '", paste(resp, collapse = ", "),
      "'. Drop `outcome` (it defaults to the response of `formula_y`) or make ",
      "them match.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# What run() and sensitivity_mnar() pass on to medfit::fit_mediation(): the
# stored `fit_args`, then any extra `...`. Extras are deprecated (set them with
# `fit_args`), still honored for one cycle, and may not repeat a stored name.
# `ipw` adds the two arguments the IPW fit supplies itself.
.md_extra_args <- function(object, dots, caller = "run()", ipw = FALSE) {
  fa <- object@fit_args
  if (length(dots)) {
    nms <- names(dots)
    if (is.null(nms) || !all(nzchar(nms))) {
      stop("Extra arguments to `", caller, "` must be named.", call. = FALSE)
    }
    dup <- intersect(nms, names(fa))
    if (length(dup)) {
      stop("`", caller, "` repeats ", paste0("`", dup, "`", collapse = ", "),
        ", already set in `fit_args`. Remove ",
        if (length(dup) > 1L) "them" else "it", " from `", caller, "`.",
        call. = FALSE
      )
    }
    warning(warningCondition(
      paste0("Passing arguments through `", caller, "` is deprecated and will ",
        "be removed in a future release: set ",
        paste0("`", nms, "`", collapse = ", "),
        " with `fit_args` in set_md_mediation()."),
      class = "md_dots_deprecated", call = NULL
    ))
  }
  extra <- c(fa, dots)
  reserved <- c(.md_reserved_args, if (ipw) c("weights", "se_type"))
  bad <- intersect(names(extra), reserved)
  if (length(bad)) {
    stop(paste0("`", bad, "`", collapse = ", "), " cannot be passed as ",
      "an extra argument: the pipeline sets ",
      if (length(bad) > 1L) "them" else "it", " itself.",
      call. = FALSE
    )
  }
  extra
}

# The model parses, the three roles are distinct and present, `mediator ~
# treatment` and `outcome ~ mediator` exist (the mediator may be latent), every
# observed variable is a data column, and fit_args cannot replace the model or
# data.
.check_lavaan_spec <- function(model, treatment, mediator, outcome, fit_args,
                               data) {
  single <- function(x) {
    is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  }
  if (!single(model)) {
    stop("`model` must be a single lavaan model syntax string.", call. = FALSE)
  }
  roles <- list(treatment = treatment, mediator = mediator, outcome = outcome)
  for (nm in names(roles)) {
    if (!single(roles[[nm]])) {
      stop("`", nm, "` must be a single variable name.", call. = FALSE)
    }
  }
  if (anyDuplicated(unlist(roles))) {
    stop("`treatment`, `mediator` and `outcome` must be different variables.",
      call. = FALSE
    )
  }
  if (!is.list(fit_args)) {
    stop("`fit_args` must be a list.", call. = FALSE)
  }
  if (length(fit_args)) {
    if (is.null(names(fit_args)) || !all(nzchar(names(fit_args)))) {
      stop("`fit_args` must be a named list.", call. = FALSE)
    }
    bad <- intersect(names(fit_args), c("model", "data"))
    if (length(bad)) {
      stop("`fit_args` cannot set ", paste0("`", bad, "`", collapse = ", "),
        ": the model and data come from set_md_mediation().",
        call. = FALSE
      )
    }
  }

  pt <- tryCatch(lavaan::lavaanify(model), error = function(e) {
    stop("`model` is not valid lavaan syntax: ", conditionMessage(e),
      call. = FALSE
    )
  })
  reg <- pt[pt$op == "~", c("lhs", "rhs")]
  if (!any(reg$lhs == mediator & reg$rhs == treatment)) {
    stop("`model` has no regression of the mediator on the treatment (`",
      mediator, " ~ ", treatment, "`).",
      call. = FALSE
    )
  }
  if (!any(reg$lhs == outcome & reg$rhs == mediator)) {
    if (!outcome %in% unique(c(pt$lhs, pt$rhs))) {
      stop("`outcome` '", outcome, "' does not appear in `model`.",
        call. = FALSE
      )
    }
    stop("`outcome` '", outcome, "' does not regress on the mediator in ",
      "`model` (`", outcome, " ~ ", mediator, "`).",
      call. = FALSE
    )
  }

  absent <- setdiff(lavaan::lavNames(pt, "ov"), names(data))
  if (length(absent)) {
    stop("Variable", if (length(absent) > 1L) "s", " ",
      paste0("'", absent, "'", collapse = ", "), " in `model` not found in ",
      "`data`.",
      call. = FALSE
    )
  }
  if (!is.numeric(data[[treatment]])) {
    stop("`treatment` '", treatment, "' must be a numeric column (0/1 for a ",
      "binary treatment, or continuous), not ", class(data[[treatment]])[1L],
      ". Recode it to numeric before calling set_md_mediation().",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# lavaan (>= 0.7-2) accepts option names with dots or underscores, in any case
# (`sampling.weights` = `sampling_weights`), and (>= 0.7-3) the same for keyword
# values (`robust.huber.white` = `robust_huber_white`). The G1 guards compare
# normalized spellings so that no spelling slips past them.
.lav_key <- function(x) tolower(gsub(".", "_", x, fixed = TRUE))

# The value of the `fit_args` entry named `name`, under any lavaan spelling.
.lav_arg <- function(fit_args, name) {
  hit <- which(.lav_key(names(fit_args)) == name)
  if (length(hit)) fit_args[[hit[1L]]] else NULL
}

# IPW with lavaan fits on the complete cases with `sampling_weights` and always
# uses robust (sandwich) SEs, like the glm IPW path (G1). A request for naive SEs
# is refused rather than overridden silently.
.check_lavaan_ipw_args <- function(fit_args, se_type = "sandwich") {
  if (!identical(se_type, "sandwich")) {
    stop("`se_type = \"", se_type, "\"` is not available for engine = ",
      "\"lavaan\" with method = \"ipw\": its SEs are always robust (sandwich).",
      call. = FALSE
    )
  }
  if ("sampling_weights" %in% .lav_key(names(fit_args))) {
    stop("`fit_args` cannot set `sampling_weights` (or `sampling.weights`): ",
      "the IPW weights are used.",
      call. = FALSE
    )
  }
  se <- .lav_arg(fit_args, "se")
  if (!is.null(se) && !identical(.lav_key(se), "robust_huber_white")) {
    stop("`fit_args$se` = ", deparse(se), " is not allowed for method = ",
      "\"ipw\": SEs must be robust (\"robust.huber.white\"), because the ",
      "weights make the model-based SEs wrong.",
      call. = FALSE
    )
  }
  est <- .lav_arg(fit_args, "estimator")
  if (!is.null(est) && !toupper(est[1L]) %in% c("ML", "MLR")) {
    stop("`fit_args$estimator` = ", deparse(est), " has no sandwich SEs with ",
      "sampling weights; use \"ML\" or \"MLR\" with method = \"ipw\".",
      call. = FALSE
    )
  }
  invisible(TRUE)
}
