# Output methods (print / summary / tidy) for the S7 classes.
#
# These are S7 methods on external generics (base::print, base/methods::summary,
# broom::tidy). They are registered at load time by S7::methods_register() (see
# zzz.R), so they dispatch without NAMESPACE S3method entries. User-facing
# documentation lives on the classes (MDMediationData / MDMediationFit /
# MDMediationResult) and the pipeline verbs (run / pool / infer).

#' @importFrom broom tidy
NULL

# print(<MDMediationData>)
S7::method(print, MDMediationData) <- function(x, ...) {
  cat("<MDMediationData>\n")
  cat("  estimator (method):", x@method, "| mechanism:", x@mechanism, "\n")
  cat("  imputations (m)   :", x@n_imputations, "\n")
  cat("  treatment / mediator:", x@treatment, "/", x@mediator, "\n")
  cat("  outcome model :", deparse(x@formula_y), "\n")
  cat("  mediator model:", deparse(x@formula_m), "\n")
  cat("  engine:", x@engine, "\n")
  invisible(x)
}

# Does a (pooled or per-imputation) medfit object carry an X:M term?
.has_xm <- function(d) S7::S7_inherits(d, medfit::InteractionMediationData)

# The pooled indirect-effect point estimate, as one line. With an X:M term the
# indirect effect a * (b + theta3 * x) depends on the treatment level, so show
# it at x = 0 and x = 1 (the pure and total natural indirect effects for a 0/1
# treatment) instead of a single a*b.
.indirect_line <- function(pooled) {
  a <- pooled@a_path
  b <- pooled@b_path
  if (!.has_xm(pooled)) {
    return(paste("indirect effect a*b =", round(a * b, 4)))
  }
  t3 <- pooled@interaction
  paste0("indirect effect a*(b + theta3*x) = ", round(a * b, 4), " at x = 0, ",
    round(a * (b + t3), 4), " at x = 1")
}

# print(<MDMediationFit>)
S7::method(print, MDMediationFit) <- function(x, ...) {
  cat("<MDMediationFit>\n")
  cat("  per-imputation fits:", x@m, "named medfit::MediationData\n")
  cat("  engine:", x@engine, "\n")
  ab <- vapply(x@per_imputation, function(d) d@a_path * d@b_path, numeric(1))
  lab <- if (.has_xm(x@per_imputation[[1]])) "a*b (at X = 0)" else "a*b"
  cat("  per-imputation", paste0(lab, ":"), "mean =", round(mean(ab), 4),
    "(range", round(min(ab), 4), "to", round(max(ab), 4), ")\n")
  cat("  -> pool() for Rubin's-rules estimates; infer() for CIs / MBCO\n")
  invisible(x)
}

# print(<MDMediationResult>)
S7::method(print, MDMediationResult) <- function(x, ...) {
  cat("<MDMediationResult> (pooled, Rubin's rules; m =", x@m, ")\n")
  # @tidy_table defaults to an empty data frame; skip it rather than fail.
  cols <- c("term", "estimate", "std_error")
  if (all(cols %in% names(x@tidy_table))) {
    key <- x@tidy_table[x@tidy_table$term %in% c("a", "b", "c_prime", "theta3"), cols]
    print(key, row.names = FALSE)
  } else {
    cat("  (no pooled estimates table)\n")
  }
  cat(" ", .indirect_line(x@pooled), "\n")
  if (.has_xm(x@pooled)) {
    cat("  -> infer(type = \"mc\", treatment_level = x) for the indirect-effect CI\n")
  } else {
    cat("  -> infer(type = \"mc\") for the indirect-effect CI\n")
  }
  invisible(x)
}

# summary(<MDMediationResult>)
S7::method(summary, MDMediationResult) <- function(object, ...) {
  cat("Pooled mediation result (Rubin's rules)\n")
  cat("  imputations (m):", object@m, "| engine:", object@engine, "\n\n")
  print(object@tidy_table, row.names = FALSE)
  cat("\n ", .indirect_line(object@pooled), "\n")
  invisible(object@tidy_table)
}

# tidy(<MDMediationResult>)  (broom::tidy, imported)
S7::method(tidy, MDMediationResult) <- function(x, ...) {
  tibble::as_tibble(x@tidy_table)
}

# print(<MDSensitivityResult>)
S7::method(print, MDSensitivityResult) <- function(x, ...) {
  cat("<MDSensitivityResult>  MNAR sensitivity curve\n")
  cat("  target(s):", paste(x@target, collapse = ", "),
    "| rungs:", nrow(x@grid), "| inference:", x@type, "\n"
  )
  cat("  seed:", x@seed, paste0("(from ", x@seed_source, ")"),
    "| target imputed by:", x@method_target, "\n"
  )
  cat("  delta applied by:", paste0(x@mechanism_used, " (",
    ifelse(x@scale == "logodds", "log-odds", "raw units"), ")", collapse = ", "), "\n")
  tb <- tidy(x)
  print(utils::head(tb, 10L), row.names = FALSE)
  if (nrow(tb) > 10L) cat("  ...", nrow(tb) - 10L, "more rung(s)\n")
  cat("\n  delta is a CONDITIONAL sensitivity parameter; `msp` is the marginal\n")
  cat("  difference actually realized. Compare msp against what you intended.\n")
  if (isTRUE(x@scale[1] == "logodds")) {
    cat("  Here delta is on the log-odds scale, while msp is a prevalence\n")
    cat("  difference on the probability scale.\n")
  }
  cat("  Assumes the supplied imputation model is compatible with the\n")
  cat("  mediation model; this is not verifiable from here.\n")
  invisible(x)
}

# summary(<MDSensitivityResult>) -- adds the tipping point
S7::method(summary, MDSensitivityResult) <- function(object, ...) {
  tb <- tidy(object)
  ordered <- all(vapply(object@grid, is.numeric, logical(1)))
  # A rung whose interval or p-value is NA has an unknown verdict, so the
  # smallest retaining departure is unknown too. Name the rungs instead of
  # searching around them (which could report a tipping point, or "none",
  # that the missing rung would contradict).
  na_rungs <- if (ordered) which(is.na(.mnar_null_retained(object, tb))) else integer()
  tp <- if (ordered && !length(na_rungs)) .mnar_tipping(object, tb) else NULL
  structure(
    list(table = tb, tipping = tp, target = object@target, type = object@type,
      ordered = ordered, na_rungs = na_rungs),
    class = "summary.MDSensitivityResult"
  )
}

# Is the null retained at each rung? Type-agnostic: an "mc" rung retains it when
# the interval covers 0; an "mbco" rung when p > alpha. Before this was
# type-aware, summary() of an mbco curve printed "no tipping point" without ever
# having looked for one.
.mnar_null_retained <- function(object, tb) {
  if (all(c("conf_low", "conf_high") %in% names(tb))) {
    return(!(tb$conf_low > 0 | tb$conf_high < 0))
  }
  if ("p_value" %in% names(tb)) {
    return(tb$p_value > (1 - object@level))
  }
  NULL
}

# The tipping point is the SMALLEST departure from MAR at which the null is
# retained -- not the first such rung in whatever order the grid was supplied.
# Distance is measured from the all-zero (MAR) row, so a multi-column grid has a
# defined ordering too; for a single column it reduces to abs(delta).
.mnar_tipping <- function(object, tb) {
  keep <- .mnar_null_retained(object, tb)
  if (is.null(keep) || !any(keep)) return(NULL)
  dist <- sqrt(rowSums(as.matrix(object@grid)^2))
  # The null already retained at MAR itself: nothing tips, the analysis is null
  # before any departure is assumed.
  if (any(dist == 0 & keep)) return(NULL)
  # NB `all(keep)` is deliberately NOT treated as "no tipping point". When the
  # grid contains no MAR rung and every rung retains the null, the conclusion
  # flips at or below the smallest departure supplied -- reporting "none found"
  # there is false reassurance in exactly the direction a sensitivity analysis
  # exists to prevent. Report the smallest, and let the caller see it sits at
  # the edge of the grid.
  cand <- which(keep)
  tb[cand[which.min(dist[cand])], , drop = FALSE]
}

#' @exportS3Method base::print
print.summary.MDSensitivityResult <- function(x, ...) {
  cat("MNAR sensitivity curve --", x$type, "| target:",
    paste(x$target, collapse = ", "), "\n\n"
  )
  print(x$table, row.names = FALSE)
  if (isFALSE(x$ordered)) {
    cat("\nTipping point not computed: a `ums` grid has no numeric ordering of\n")
    cat("departures from MAR, so \"smallest departure\" is undefined.\n")
  } else if (length(x$na_rungs)) {
    cat("\nTipping point not computed: rung(s)", paste(x$na_rungs, collapse = ", "),
      "have a missing (NA)\n")
    cat("interval or p-value, so whether the null is retained there is unknown.\n")
  } else if (is.null(x$tipping)) {
    cat("\nNo tipping point within the supplied grid.\n")
  } else {
    d <- x$tipping[[1L]]
    cat("\nTipping point: the smallest departure at which the null is\n",
      " retained is delta =", d,
      "(realized msp =", round(x$tipping$msp, 4), ").\n"
    )
    cat("A CSP-scale tipping point has no direct clinical reading -- judge\n")
    cat("plausibility on the realized msp, and only call the result fragile if\n")
    cat("that departure from MAR is itself plausible.\n")
  }
  invisible(x)
}

# Columns tidy(<MDSensitivityResult>) appends to the grid. A target may not
# share one of these names (checked in sensitivity_mnar()), or its delta column
# would be overwritten. Keep this list in step with the method below.
.mnar_tidy_reserved <- c(
  "msp", "estimate", "conf_low", "conf_high", "D4", "p_value",
  "mechanism", "scale"
)

# tidy(<MDSensitivityResult>) -- one row per rung
S7::method(tidy, MDSensitivityResult) <- function(x, ...) {
  base <- x@grid
  # The validator allows an empty @msp; report it as NA rather than fail.
  base$msp <- if (length(x@msp)) x@msp else NA_real_
  if (identical(x@type, "mc")) {
    base$estimate <- vapply(x@rungs, function(r) as.numeric(r$Estimate)[1], numeric(1))
    base$conf_low <- vapply(x@rungs, function(r) as.numeric(r$CI)[1], numeric(1))
    base$conf_high <- vapply(x@rungs, function(r) as.numeric(r$CI)[2], numeric(1))
  } else {
    base$D4 <- vapply(x@rungs, function(r) unname(r[["D4"]]), numeric(1))
    base$p_value <- vapply(x@rungs, function(r) unname(r[["p"]]), numeric(1))
  }
  base$mechanism <- paste(x@mechanism_used, collapse = ",")
  base$scale <- paste(x@scale, collapse = ",")
  tibble::as_tibble(base)
}

# print(<MbcoMIResult>). Registered on base::print, not the namespace's
# `print`: import(OpenMx) makes that an S4 generic, and MbcoMIResult cannot be
# S4_register()ed (see R/MbcoMIResult.R). The S4 default falls through to
# base::print's S3 dispatch.
S7::`method<-`(base::print, MbcoMIResult, value = function(x, ...) {
  v <- S7::S7_data(x)
  cat("<MbcoMIResult> D4-stacked MBCO test of H0: a*b = 0 (m =", x@m, "imputations)\n")
  cat("  D4 =", format(v[["D4"]], digits = 4), "on F(", sep = " ")
  cat(x@k, ", ", format(v[["nu"]], digits = 4), "), p = ",
    format.pval(v[["p"]], digits = 4), "\n", sep = "")
  cat("  r4 =", format(v[["r4"]], digits = 4), paste0("(ariv = \"", x@ariv, "\")"),
    "| d_S =", format(v[["d_S"]], digits = 4), "\n")
  cat("  stacked constrained fit:", paste0(x@stacked_branch, " = 0"), "branch\n")
  cat("  imputations on the a = 0 branch: ", format(100 * x@p_branch_a, digits = 3),
    "% (", if (x@branch_mix) "mixed" else "not mixed", ")\n", sep = "")
  invisible(x)
})

# tidy(<MbcoMIResult>)  (broom::tidy, imported)
S7::method(tidy, MbcoMIResult) <- function(x, ...) {
  v <- S7::S7_data(x)
  tibble::tibble(
    term = "indirect", statistic = v[["D4"]], df1 = x@k, df2 = v[["nu"]],
    p_value = v[["p"]], r4 = v[["r4"]], d_S = v[["d_S"]], ariv = x@ariv,
    stacked_branch = x@stacked_branch, branch_mix = x@branch_mix,
    p_branch_a = x@p_branch_a, m = x@m
  )
}
