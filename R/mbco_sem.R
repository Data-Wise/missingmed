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
  rows <- vapply(seq_len(nrow(pt)), function(i) {
    .mm_pt_row_syntax(pt, i, label = if (i == row_a) lab_a else if (i == row_b) lab_b)
  }, "")
  cons <- vapply(attr(pt, "constraints") %||% list(), function(z) {
    paste(z$lhs, z$op, z$rhs)
  }, "")
  list(model = paste(c(rows, cons), collapse = "\n"), a = lab_a, b = lab_b)
}
