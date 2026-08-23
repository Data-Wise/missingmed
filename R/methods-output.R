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

# print(<MDMediationFit>)
S7::method(print, MDMediationFit) <- function(x, ...) {
  cat("<MDMediationFit>\n")
  cat("  per-imputation fits:", x@m, "named medfit::MediationData\n")
  cat("  engine:", x@engine, "\n")
  ab <- vapply(x@per_imputation, function(d) d@a_path * d@b_path, numeric(1))
  cat("  per-imputation a*b: mean =", round(mean(ab), 4),
    "(range", round(min(ab), 4), "to", round(max(ab), 4), ")\n")
  cat("  -> pool() for Rubin's-rules estimates; infer() for CIs / MBCO\n")
  invisible(x)
}

# print(<MDMediationResult>)
S7::method(print, MDMediationResult) <- function(x, ...) {
  cat("<MDMediationResult> (pooled, Rubin's rules; m =", x@m, ")\n")
  key <- x@tidy_table[x@tidy_table$term %in% c("a", "b", "c_prime"),
    c("term", "estimate", "std_error")]
  print(key, row.names = FALSE)
  cat("  indirect effect a*b =", round(x@pooled@a_path * x@pooled@b_path, 4), "\n")
  cat("  -> infer(type = \"mc\") for the indirect-effect CI\n")
  invisible(x)
}

# summary(<MDMediationResult>)
S7::method(summary, MDMediationResult) <- function(object, ...) {
  cat("Pooled mediation result (Rubin's rules)\n")
  cat("  imputations (m):", object@m, "| engine:", object@engine, "\n\n")
  print(object@tidy_table, row.names = FALSE)
  cat("\n  a*b =", round(object@pooled@a_path * object@pooled@b_path, 4), "\n")
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
  tb <- tidy(x)
  print(utils::head(tb, 10L), row.names = FALSE)
  if (nrow(tb) > 10L) cat("  ...", nrow(tb) - 10L, "more rung(s)\n")
  cat("\n  delta is a CONDITIONAL sensitivity parameter; `msp` is the marginal\n")
  cat("  difference actually realized. Compare msp against what you intended.\n")
  cat("  Assumes the supplied imputation model is compatible with the\n")
  cat("  mediation model; this is not verifiable from here.\n")
  invisible(x)
}

# summary(<MDSensitivityResult>) -- adds the tipping point
S7::method(summary, MDSensitivityResult) <- function(object, ...) {
  tb <- tidy(object)
  tp <- NULL
  if (all(c("conf_low", "conf_high") %in% names(tb))) {
    excl <- tb$conf_low > 0 | tb$conf_high < 0
    if (any(excl) && any(!excl)) {
      first_null <- which(!excl)[1L]
      tp <- tb[first_null, , drop = FALSE]
    }
  }
  structure(
    list(table = tb, tipping = tp, target = object@target, type = object@type),
    class = "summary.MDSensitivityResult"
  )
}

#' @exportS3Method base::print
print.summary.MDSensitivityResult <- function(x, ...) {
  cat("MNAR sensitivity curve --", x$type, "| target:",
    paste(x$target, collapse = ", "), "\n\n"
  )
  print(x$table, row.names = FALSE)
  if (is.null(x$tipping)) {
    cat("\nNo tipping point within the supplied grid.\n")
  } else {
    d <- x$tipping[[1L]]
    cat("\nTipping point: the interval first includes 0 at delta =", d,
      "(realized msp =", round(x$tipping$msp, 4), ").\n"
    )
    cat("A CSP-scale tipping point has no direct clinical reading -- judge\n")
    cat("plausibility on the realized msp, and only call the result fragile if\n")
    cat("that departure from MAR is itself plausible.\n")
  }
  invisible(x)
}

# tidy(<MDSensitivityResult>) -- one row per rung
S7::method(tidy, MDSensitivityResult) <- function(x, ...) {
  base <- x@grid
  base$msp <- x@msp
  if (identical(x@type, "mc")) {
    base$estimate <- vapply(x@rungs, function(r) as.numeric(r$Estimate)[1], numeric(1))
    base$conf_low <- vapply(x@rungs, function(r) as.numeric(r$CI)[1], numeric(1))
    base$conf_high <- vapply(x@rungs, function(r) as.numeric(r$CI)[2], numeric(1))
  } else {
    base$D4 <- vapply(x@rungs, function(r) unname(r[["D4"]]), numeric(1))
    base$p_value <- vapply(x@rungs, function(r) unname(r[["p"]]), numeric(1))
  }
  tibble::as_tibble(base)
}
