# MBCO for engine = "lavaan" on medfit's mbco_sem()
# (SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md). T1: label the a and b paths.
#
# medfit::mbco_sem() refits "<label> == 0", so both tested paths need a label in
# the syntax. The model is parsed with lavaan::lavParseModelString() and written
# back from the parse, never edited as text: a line-based regex breaks on
# `;`-separated statements and corrupts a formula continued on the next line.

# One column of a lavaan parse table as character, "" when the parse has none.
.mm_pt_col <- function(pt, name) {
  if (name %in% names(pt)) {
    out <- as.character(pt[[name]])
    out[is.na(out)] <- ""
    out
  } else {
    rep("", nrow(pt))
  }
}

# The syntax of one parse row: `lhs op modifiers*rhs`.
.mm_pt_row_syntax <- function(pt, i, label = NULL) {
  g <- function(name) .mm_pt_col(pt, name)[i]
  lab <- label %||% g("label")
  if (nzchar(lab) && grepl(";", lab, fixed = TRUE)) {
    lab <- paste0("c(", gsub(";", ",", lab, fixed = TRUE), ")")
  }
  mods <- c(
    if (nzchar(g("fixed"))) g("fixed"),
    if (nzchar(lab)) lab,
    if (nzchar(g("start"))) paste0("start(", g("start"), ")"),
    if (nzchar(g("lower"))) paste0("lower(", g("lower"), ")"),
    if (nzchar(g("upper"))) paste0("upper(", g("upper"), ")"),
    if (nzchar(g("prior"))) paste0("prior(", g("prior"), ")")
  )
  op <- pt$op[i]
  rhs <- if (identical(op, "~1")) "1" else pt$rhs[i]
  op <- if (identical(op, "~1")) "~" else op
  paste0(pt$lhs[i], " ", op, " ", paste0(c(mods, ""), collapse = "*"), rhs)
}

# The tested row `lhs ~ rhs` of a parse: exactly one, estimated, carrying at most
# a label. Returns its index.
.mm_sem_tested_row <- function(pt, lhs, rhs, role) {
  hit <- which(pt$op == "~" & pt$lhs == lhs & pt$rhs == rhs)
  if (length(hit) != 1L) {
    stop("MBCO needs exactly one `", lhs, " ~ ", rhs, "` regression (the ", role,
      " path) in the lavaan model; found ", length(hit), ".",
      call. = FALSE
    )
  }
  fixed <- .mm_pt_col(pt, "fixed")[hit]
  if (nzchar(fixed)) {
    stop("The `", lhs, " ~ ", rhs, "` path (the ", role, " path) is fixed in the ",
      "lavaan model, not estimated, so there is no parameter to test. Free it, or ",
      "use type = \"mc\".",
      call. = FALSE
    )
  }
  extra <- c("start", "lower", "upper", "prior")
  extra <- extra[vapply(extra, function(n) nzchar(.mm_pt_col(pt, n)[hit]), NA)]
  if (length(extra)) {
    stop("The `", lhs, " ~ ", rhs, "` path (the ", role, " path) carries a `",
      extra[[1L]], "()` modifier. MBCO labels this path and medfit takes one ",
      "modifier per term: remove the `", extra[[1L]], "()` modifier.",
      call. = FALSE
    )
  }
  if (grepl(";", .mm_pt_col(pt, "label")[hit], fixed = TRUE)) {
    stop("The `", lhs, " ~ ", rhs, "` path (the ", role, " path) has one label per ",
      "group: MBCO does not support a multi-group model.",
      call. = FALSE
    )
  }
  hit
}

# `model` (lavaan syntax) with the a (`mediator ~ treatment`) and b
# (`outcome ~ mediator`) paths labeled. An existing label is reused. Returns
# list(model, a, b): the syntax and the two labels.
.mm_sem_label_model <- function(model, treatment, mediator, outcome) {
  model <- paste(model, collapse = "\n")
  pt <- lavaan::lavParseModelString(model, as.data.frame. = TRUE, warn = FALSE)
  # lavaan normalizes c(a)*, label("a")* and multi-lhs rows, losing the
  # original construct. Inspect expression structure before rewriting; never
  # use text substitution to inject labels or guess regression boundaries.
  expressions <- tryCatch(parse(text = model), error = function(e) {
    stop("Unsupported MBCO syntax while validating modifiers: ", conditionMessage(e), call. = FALSE)
  })
  check <- function(x) {
    if (!is.call(x)) return(invisible(NULL))
    op <- as.character(x[[1L]])
    if (op == "*" && is.call(x[[2L]]) &&
        (as.character(x[[2L]][[1L]]) == "label" ||
          (as.character(x[[2L]][[1L]]) == "c" && length(x[[2L]]) == 2L))) {
      stop("The ", as.character(x[[2L]][[1L]]),
        "() modifier is unsupported by MBCO.", call. = FALSE)
    }
    if (op == "~" && length(x) == 3L && is.call(x[[2L]]) &&
        as.character(x[[2L]][[1L]]) == "+") {
      stop("The multi-lhs regression is unsupported by MBCO.", call. = FALSE)
    }
    invisible(lapply(as.list(x)[-1L], check))
  }
  invisible(lapply(as.list(expressions), check))
  if (any(nzchar(.mm_pt_col(pt, "efa")))) {
    stop("The efa() modifier is unsupported by MBCO.", call. = FALSE)
  }
  for (field in c("fixed", "label", "start", "lower", "upper", "prior")) {
    if (any(grepl(";", .mm_pt_col(pt, field), fixed = TRUE))) {
      stop("The multi-group c() modifier is unsupported by MBCO.", call. = FALSE)
    }
  }
  fixed <- .mm_pt_col(pt, "fixed")
  parsed_labels <- .mm_pt_col(pt, "label")
  if (any(nzchar(parsed_labels) & !grepl("^[[:alpha:].][[:alnum:]_.]*$", parsed_labels))) {
    stop("Unsupported equal() or non-identifier label modifier in MBCO.", call. = FALSE)
  }
  if (any(nzchar(fixed) & is.na(suppressWarnings(as.numeric(fixed))) & fixed != "NA")) {
    stop("Unsupported equal() or nonnumeric fixed modifier in MBCO.", call. = FALSE)
  }
  if (any(.mm_pt_col(pt, "fixed") == "NA")) {
    stop("The `NA*` (free first loading) modifier is not supported by MBCO: ",
      "medfit's fit_sem() refuses it. Fix the loading with `1*` or use ",
      "`std.lv = TRUE` instead.",
      call. = FALSE
    )
  }
  row_a <- .mm_sem_tested_row(pt, mediator, treatment, "a")
  row_b <- .mm_sem_tested_row(pt, outcome, mediator, "b")
  labels <- .mm_pt_col(pt, "label")
  used <- unlist(strsplit(labels[nzchar(labels)], ";", fixed = TRUE))
  constraints <- attr(pt, "constraints") %||% list()
  used <- c(used, unlist(lapply(constraints, function(z) {
    c(all.vars(str2lang(z$lhs)), all.vars(str2lang(z$rhs)))
  })))
  fresh <- function(base, taken) {
    while (base %in% taken) base <- paste0(base, "_")
    base
  }
  lab_a <- if (nzchar(labels[row_a])) labels[row_a] else fresh("mm_a", used)
  used <- c(used, lab_a)
  lab_b <- if (nzchar(labels[row_b])) labels[row_b] else fresh("mm_b", used)
  if (identical(lab_a, lab_b)) {
    stop("The a and b paths have the same label (`", lab_a, "`): they would be one ",
      "parameter, so there is no separate path to test.",
      call. = FALSE
    )
  }
  # Repeated labels remain one parameter, but a zero variance is outside the
  # nonsingular Gaussian likelihood domain required by the branch comparison.
  variance <- pt$op == "~~" & pt$lhs == pt$rhs
  for (tested in c(lab_a, lab_b)) {
    if (any(variance & labels == tested)) {
      stop("Tested label `", tested, "` also labels a variance: its zero null ",
        "has a singular variance domain and is unsupported by MBCO.", call. = FALSE)
    }
  }
  rows <- vapply(seq_len(nrow(pt)), function(i) {
    .mm_pt_row_syntax(pt, i, label = if (i == row_a) lab_a else if (i == row_b) lab_b)
  }, "")
  cons <- vapply(attr(pt, "constraints") %||% list(), function(z) {
    paste(z$lhs, z$op, z$rhs)
  }, "")
  list(model = paste(c(rows, cons), collapse = "\n"), a = lab_a, b = lab_b)
}

# No installed medfit completeness ledger is assumed. Restrict equalities to
# affine expressions: nonlinear/product input constraints can enumerate hidden
# union branches, including inside the two mbco_sem refits.
.mm_sem_affine <- function(x) {
  if (is.numeric(x) || is.name(x)) return(TRUE)
  if (!is.call(x)) return(FALSE)
  op <- as.character(x[[1L]])
  args <- as.list(x)[-1L]
  if (op %in% c("(", "+", "-")) return(all(vapply(args, .mm_sem_affine, NA)))
  if (op == "*" && length(args) == 2L) {
    return(any(vapply(args, is.numeric, NA)) && all(vapply(args, .mm_sem_affine, NA)))
  }
  FALSE
}

.mm_sem_complete_syntax <- function(model) {
  pt <- lavaan::lavParseModelString(model, as.data.frame. = TRUE, warn = FALSE)
  constraints <- attr(pt, "constraints") %||% list()
  defined <- vapply(Filter(function(z) z$op == ":=", constraints), function(z) z$lhs, "")
  if (any(nzchar(.mm_pt_col(pt, "lower"))) || any(nzchar(.mm_pt_col(pt, "upper")))) {
    stop("Unresolved branch completeness: bounded parameters are unsupported.", call. = FALSE)
  }
  for (z in constraints) {
    if (z$op == ":=") next
    sides <- lapply(c(z$lhs, z$rhs), function(s) str2lang(s))
    aliases <- intersect(unlist(lapply(sides, all.vars)), defined)
    unknown <- setdiff(unlist(lapply(sides, all.vars)), .mm_pt_col(pt, "label"))
    if (length(unknown)) {
      stop("Unresolved branch completeness: constraint symbols must be model parameter labels.",
        call. = FALSE)
    }
    if (z$op != "==" || length(aliases) || !all(vapply(sides, .mm_sem_affine, NA))) {
      stop("Unresolved branch completeness: nonlinear or inequality constraints ",
        "are unsupported without a dependency branch ledger.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

.mm_sem_fit <- function(model, d) {
  if (utils::packageVersion("medfit") < "0.10.0") {
    stop("The SEM provider requires medfit >= 0.10.0.", call. = FALSE)
  }
  observed <- lavaan::lavNames(lavaan::lavaanify(model), "ov")
  for (name in intersect(observed, names(d))) {
    x <- d[[name]]
    if (is.factor(x) && nlevels(x) != 2L) {
      stop("SEM MBCO requires a 2-level factor: `", name, "` has ",
        nlevels(x), " levels.", call. = FALSE)
    }
    if (!is.numeric(x) && !is.factor(x)) {
      stop("SEM MBCO model variable `", name, "` must be numeric or a 2-level factor.",
        call. = FALSE)
    }
  }
  fit <- medfit::fit_sem(model, d, fixed_x = FALSE, meanstructure = NULL)
  if (!is.finite(fit@f)) stop("Non-finite full-fit discrepancy.", call. = FALSE)
  list(fit = fit, n_obs = fit@n_obs, improper = fit@diagnostics$improper)
}

# Exported-fit fallback permitted by spec section 3. It is diagnostic only:
# mbco_sem remains the source of LR values and both discrepancies must match.
.mm_sem_refit_diagnostics <- function(fit, label, d) {
  if (length(fit@internals$fixed_x)) {
    stop("Diagnostic refit requires the approved fixed_x = FALSE state.", call. = FALSE)
  }
  null <- medfit::fit_sem(paste(fit@model, paste(label, "== 0"), sep = "\n"),
    d, information = fit@information,
    n_starts = fit@internals$n_starts, control = fit@internals$control,
    meanstructure = if (isTRUE(fit@internals$ram$has_mean)) TRUE else NULL,
    fixed_x = FALSE)
  if (!identical(null@internals$factors, fit@internals$factors) ||
      !identical(null@internals$fixed_x, fit@internals$fixed_x)) {
    stop("Diagnostic refit factor/fixed-x state does not match the full fit.", call. = FALSE)
  }
  list(f = null@f, n_obs = null@n_obs, improper = null@diagnostics$improper)
}

.mm_sem_mbco <- function(fit, a, b) medfit::mbco_sem(fit, a, b)

.mm_sem_attribute_nulls <- function(fit, a, b, mb, d) {
  labels <- c(a, b)
  tab <- mb$tests
  if (!is.data.frame(tab) || nrow(tab) != 2L ||
      !identical(as.character(tab$constraint), paste(labels, "== 0"))) {
    stop("Unresolved null-warning attribution: incomplete branch table.", call. = FALSE)
  }
  improper <- vapply(seq_along(labels), function(i) {
    null <- tryCatch(.mm_sem_refit_diagnostics(fit, labels[i], d), error = function(e) {
      stop("The ", c("a", "b")[i], " = 0 diagnostic refit failed: ",
        conditionMessage(e), call. = FALSE)
    })
    lr <- fit@n_obs * (null$f - fit@f)
    if (!identical(as.numeric(null$n_obs), as.numeric(fit@n_obs)) ||
        length(lr) != 1L || !is.finite(lr) ||
        !is.finite(tab$diff_ll[i]) || abs(lr - tab$diff_ll[i]) > 1e-7) {
      stop("Unresolved null-warning attribution: ", c("a", "b")[i],
        " = 0 diagnostic refit does not match the reported LR/sample.", call. = FALSE)
    }
    isTRUE(null$improper) || (is.character(null$improper) && length(null$improper) > 0L)
  }, NA)
  if (!any(improper)) {
    stop("Unresolved null-warning attribution: diagnostic refits did not reproduce it.",
      call. = FALSE)
  }
  mb$improper <- c("a", "b")[improper]
  mb
}

# Fourier-Motzkin elimination for A x >= rhs, with unrestricted coordinates.
# A finite work cap refuses unresolved cases rather than assuming feasibility.
.mm_sem_feasible <- function(mat, rhs, variance_columns) {
  positive <- diag(ncol(mat))[variance_columns, , drop = FALSE]
  rows <- rbind(cbind(mat, rhs), cbind(-mat, -rhs),
    cbind(positive, rep(1e-10, nrow(positive))))
  for (column in seq_len(ncol(mat))) {
    scale <- apply(abs(rows), 1L, max)
    rows <- rows / pmax(scale, 1e-300)
    coefficient <- rows[, 1L]
    if (any(coefficient != 0 & abs(coefficient) <= 1e-12)) {
      stop("Unresolved joint variance feasibility: ill-scaled elimination coefficient.", call. = FALSE)
    }
    plus <- which(coefficient > 1e-12)
    minus <- which(coefficient < -1e-12)
    flat <- rows[abs(coefficient) <= 1e-12, -1L, drop = FALSE]
    if (length(plus) * length(minus) + nrow(flat) > 4096L) {
      stop("Unresolved joint variance feasibility: elimination limit exceeded.", call. = FALSE)
    }
    pairs <- lapply(plus, function(i) {
      if (!length(minus)) return(NULL)
      sweep(rows[minus, -1L, drop = FALSE], 1L, -coefficient[minus], "/") +
        matrix(rows[i, -1L] / coefficient[i], length(minus), ncol(rows) - 1L, byrow = TRUE)
    })
    rows <- do.call(rbind, c(list(flat), pairs))
    if (!nrow(rows)) return(TRUE)
  }
  all(rows[, 1L] <= 1e-12)
}

# Check that each tested equality removes a dimension beyond existing affine
# equalities. Otherwise mbco_sem's fixed df=1 is not the comparison requested.
.mm_sem_dimensions <- function(model, a, b) {
  pt <- lavaan::lavParseModelString(model, as.data.frame. = TRUE, warn = FALSE)
  cons <- Filter(function(z) z$op == "==", attr(pt, "constraints") %||% list())
  labels <- .mm_pt_col(pt, "label")
  variances <- unique(labels[pt$op == "~~" & pt$lhs == pt$rhs & nzchar(labels)])
  vars <- unique(c(a, b, variances, unlist(lapply(cons, function(z) {
    c(all.vars(str2lang(z$lhs)), all.vars(str2lang(z$rhs)))
  }))))
  zero <- as.list(setNames(rep(0, length(vars)), vars))
  constants <- vapply(cons, function(z) {
    eval(str2lang(z$rhs), zero, baseenv()) - eval(str2lang(z$lhs), zero, baseenv())
  }, 0.0)
  rows <- lapply(cons, function(z) {
    expr <- str2lang(paste0("(", z$lhs, ")-(", z$rhs, ")"))
    origin <- eval(expr, zero, baseenv())
    vapply(vars, function(v) {
      unit <- zero
      unit[[v]] <- 1
      eval(expr, unit, baseenv()) - origin
    }, 0.0)
  })
  mat <- if (length(rows)) do.call(rbind, rows) else matrix(0, 0, length(vars))
  if (any(!is.finite(mat)) || any(!is.finite(constants))) {
    stop("Non-finite affine constraint geometry.", call. = FALSE)
  }
  if (!.mm_sem_feasible(mat, constants, match(variances, vars))) {
    stop("Inconsistent equalities or infeasible full-model variance domain.", call. = FALSE)
  }
  rank <- function(x) if (!nrow(x)) 0L else qr(t(x), tol = 1e-10)$rank
  for (v in c(a, b)) {
    unit <- as.numeric(vars == v)
    if (rank(rbind(mat, unit)) - rank(mat) != 1L) {
      stop("The ", v, " = 0 null removes no additional dimension; MBCO requires k = 1.",
        call. = FALSE)
    }
    null <- rbind(mat, unit)
    rhs <- c(constants, 0)
    if (!.mm_sem_feasible(null, rhs, match(variances, vars))) {
      stop("The ", v, " = 0 null has inconsistent equalities or an infeasible joint variance domain.",
        call. = FALSE)
    }
    # Independent rows span the affine closure, including transitive equalities.
    basis <- qr(t(null), tol = 1e-10)
    keep <- basis$pivot[seq_len(basis$rank)]
    for (variance in variances) {
      coordinate <- as.numeric(vars == variance)
      if (rank(rbind(null, coordinate)) == rank(null)) {
        weights <- qr.solve(t(null[keep, , drop = FALSE]), coordinate, tol = 1e-10)
        value <- sum(weights * rhs[keep])
        if (!is.finite(value) || value <= 1e-10) {
          stop("The ", v, " = 0 null forces variance `", variance,
            "` nonpositive (or numerically zero); unsupported variance domain.", call. = FALSE)
        }
      }
    }
  }
  invisible(TRUE)
}

# Raw LR tolerance, before stack/K scaling. Absolute rather than likelihood-
# relative: large likelihood offsets must never excuse a material violation.
# The fixed 1e-7 resolution is checked against stored-data oracle differences in
# test-mbco-sem-provider.R; it is not a global-optimality certificate. Negatives
# within that resolution are reported and rounded to zero, never silently floored.
.mm_sem_lr <- function(x, branch) {
  if (length(x) != 1L || !is.finite(x)) {
    stop("Non-finite LR summary for ", branch, ".", call. = FALSE)
  }
  if (x < -1e-7) {
    stop("Unresolved negative LR for ", branch, " (", x, " raw LR units).", call. = FALSE)
  }
  if (x < 0) {
    warning("Roundoff-sized negative LR for ", branch, " rounded to zero.", call. = FALSE)
    x <- 0
  }
  x
}

# Approved spec 3a: these lavaan options do not change the supported statistic.
# They are deliberately ignored, not forwarded or translated to medfit.
.mm_sem_check_args <- function(fit_args) {
  if (!is.list(fit_args) || is.data.frame(fit_args)) {
    stop("`fit_args` must be a named list.", call. = FALSE)
  }
  if (!length(fit_args)) return(invisible(TRUE))
  nm <- names(fit_args)
  if (is.null(nm) || anyNA(nm) || any(!nzchar(nm))) {
    stop("Every `fit_args` option must have a nonempty name.", call. = FALSE)
  }
  keys <- .lav_key(nm)
  if (anyDuplicated(keys)) {
    stop("Duplicate `fit_args` option: `", nm[duplicated(keys)][1L], "`.", call. = FALSE)
  }
  allowed <- c("estimator", "std_lv", "std_ov", "fixed_x", "conditional_x",
    "meanstructure", "information", "missing", "se", "test")
  bad <- nm[!keys %in% allowed]
  if (length(bad)) {
    stop("Unsupported SEM MBCO `fit_args` option: `", bad[1L], "`.", call. = FALSE)
  }
  if ("estimator" %in% keys) {
    estimator <- fit_args[[which(keys == "estimator")]]
    if (!is.character(estimator) || length(estimator) != 1L || is.na(estimator) ||
      toupper(estimator) != "ML") {
      stop("SEM MBCO `fit_args` `estimator` must be \"ML\".", call. = FALSE)
    }
  }
  invisible(TRUE)
}

.mm_sem_provider <- function(model, treatment, mediator, outcome, fit_args = list()) {
  .mm_sem_check_args(fit_args)
  .mm_sem_complete_syntax(model)
  lab <- .mm_sem_label_model(model, treatment, mediator, outcome)
  .mm_sem_dimensions(lab$model, lab$a, lab$b)
  function(d) {
    notices <- new.env(parent = emptyenv())
    notices$messages <- character()
    collect <- function(w) {
      notices$messages <- c(notices$messages, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
    out <- tryCatch(withCallingHandlers({
    full <- tryCatch(.mm_sem_fit(lab$model, d), error = function(e) {
      stop("The full model did not converge or is unresolved: ", conditionMessage(e), call. = FALSE)
    })
    if (!identical(as.numeric(full$n_obs), as.numeric(nrow(d)))) {
      stop("The full model dropped observations.", call. = FALSE)
    }
    before <- length(notices$messages)
    mb <- .mm_sem_mbco(full$fit, lab$a, lab$b)
    null_notices <- notices$messages[seq_along(notices$messages) > before]
    if (any(grepl("^improper solution:", null_notices, ignore.case = TRUE)) &&
        length(mb$improper) == 0L) {
      mb <- .mm_sem_attribute_nulls(full$fit, lab$a, lab$b, mb, d)
    }
    tab <- mb$tests
    expected <- paste(c(lab$a, lab$b), "== 0")
    if (!is.data.frame(tab) || nrow(tab) != 2L || !identical(as.character(tab$constraint), expected) ||
        !all(tab$converged %in% TRUE) || length(tab$converged) != 2L ||
        length(tab$f) != 2L || any(!is.finite(tab$f)) || length(tab$diff_ll) != 2L) {
      stop("Unresolved or incomplete a = 0 / b = 0 refits.", call. = FALSE)
    }
    lr <- vapply(seq_len(2L), function(i) .mm_sem_lr(tab$diff_ll[i], expected[i]), 0.0)
    out <- c(full = 0, a = -lr[1L] / 2, b = -lr[2L] / 2, k_a = 1, k_b = 1)
    # medfit diagnostics$improper is a character vector of diagnostic details,
    # not a logical flag; keep support for the logical adapter test double.
    improper <- isTRUE(full$improper) ||
      (is.character(full$improper) && length(full$improper) > 0L)
    attr(out, "improper") <- c(if (improper) "full" else character(), mb$improper)
    out
    }, warning = collect), error = function(e) {
      detail <- if (length(notices$messages)) {
        paste0(" Collected warnings: ", paste(unique(notices$messages), collapse = "; "))
      } else {
        ""
      }
      stop(conditionMessage(e), detail, call. = FALSE)
    })
    attr(out, "sem_warnings") <- unique(notices$messages)
    out
  }
}
