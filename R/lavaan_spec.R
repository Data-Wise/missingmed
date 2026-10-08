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
  given <- c(model = !is.null(model), outcome = !is.null(outcome))
  if (any(given)) {
    nm <- names(given)[given][1L]
    stop("`", nm, "` is only used with engine = \"lavaan\".", call. = FALSE)
  }
  if (length(fit_args)) {
    stop("`fit_args` is only used with engine = \"lavaan\"; pass extra ",
      "arguments for the other engines through run().",
      call. = FALSE
    )
  }
  invisible(TRUE)
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
