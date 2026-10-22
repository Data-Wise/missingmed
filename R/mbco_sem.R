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
  fit <- medfit::fit_sem(model, d, fixed_x = FALSE)
  if (!is.finite(fit@f)) stop("Non-finite full-fit discrepancy.", call. = FALSE)
  list(fit = fit, n_obs = fit@n_obs, improper = fit@diagnostics$improper)
}

.mm_sem_mbco <- function(fit, a, b) medfit::mbco_sem(fit, a, b)

# Check that each tested equality removes a dimension beyond existing affine
# equalities. Otherwise mbco_sem's fixed df=1 is not the comparison requested.
.mm_sem_dimensions <- function(model, a, b) {
  pt <- lavaan::lavParseModelString(model, as.data.frame. = TRUE, warn = FALSE)
  cons <- Filter(function(z) z$op == "==", attr(pt, "constraints") %||% list())
  vars <- unique(c(a, b, unlist(lapply(cons, function(z) {
    c(all.vars(str2lang(z$lhs)), all.vars(str2lang(z$rhs)))
  }))))
  zero <- as.list(setNames(rep(0, length(vars)), vars))
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
  rank <- function(x) if (!nrow(x)) 0L else qr(t(x), tol = 1e-10)$rank
  for (v in c(a, b)) {
    unit <- as.numeric(vars == v)
    if (rank(rbind(mat, unit)) - rank(mat) != 1L) {
      stop("The ", v, " = 0 null removes no additional dimension; MBCO requires k = 1.",
        call. = FALSE)
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

.mm_sem_provider <- function(model, treatment, mediator, outcome, fit_args = list()) {
  # T3 owns option translation. Until then, never silently discard an option.
  if (length(fit_args)) stop("SEM provider fit_args support awaits T3.", call. = FALSE)
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
    mb <- .mm_sem_mbco(full$fit, lab$a, lab$b)
    tab <- mb$tests
    expected <- paste(c(lab$a, lab$b), "== 0")
    if (!is.data.frame(tab) || nrow(tab) != 2L || !identical(as.character(tab$constraint), expected) ||
        !all(tab$converged %in% TRUE) || length(tab$converged) != 2L ||
        length(tab$f) != 2L || any(!is.finite(tab$f)) || length(tab$diff_ll) != 2L) {
      stop("Unresolved or incomplete a = 0 / b = 0 refits.", call. = FALSE)
    }
    lr <- vapply(seq_len(2L), function(i) .mm_sem_lr(tab$diff_ll[i], expected[i]), 0.0)
    out <- c(full = 0, a = -lr[1L] / 2, b = -lr[2L] / 2, k_a = 1, k_b = 1)
    attr(out, "improper") <- if (isTRUE(full$improper)) "full" else character()
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
