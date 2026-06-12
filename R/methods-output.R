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
