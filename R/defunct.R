# The S4 API was deprecated in 0.5.0 and is removed in 0.6.0. Each stub below
# names its replacement; the stubs are deleted in 0.7.0. Everything else of the
# S4 API (the classes, the predicates is_fit()/is_pd()/is_lav_syntax()/
# is_valid_lav_syntax(), the tidy() methods for OpenMx models and logLik
# objects) is removed without a stub: nothing in the S7 pipeline uses them.

#' Defunct S4 functions
#'
#' These functions belonged to the S4 interface, which was removed in
#' missingmed 0.6.0. Each one now stops with a message naming its replacement.
#' See `vignette("s4-migration", package = "missingmed")`.
#'
#' | Defunct | Replacement |
#' |---|---|
#' | `set_sem()` | [set_md_mediation()], with `engine = "lavaan"` for a structural equation model |
#' | `run_sem()` | [run()] |
#' | `pool_sem()` | [pool()] |
#' | `fit_model()`, `lav_mice()` | [run()] fits every imputation |
#' | `mx_mice()` | none: OpenMx models are no longer supported |
#'
#' @param ... Ignored.
#' @return Never returns; always an error of class `defunctError`.
#' @name missingmed-defunct
#' @aliases set_sem run_sem pool_sem fit_model lav_mice mx_mice
NULL

.defunct_s4 <- function(old, new) {
  .Defunct(msg = paste0(
    "`", old, "()` was removed in missingmed 0.6.0 with the S4 API. ", new,
    " See vignette(\"s4-migration\", package = \"missingmed\")."
  ))
}

#' @rdname missingmed-defunct
#' @export
set_sem <- function(...) {
  .defunct_s4("set_sem", paste0(
    "Use set_md_mediation(); pass `model` (lavaan syntax), `outcome` and ",
    "`engine = \"lavaan\"` for a structural equation model."
  ))
}

#' @rdname missingmed-defunct
#' @export
run_sem <- function(...) .defunct_s4("run_sem", "Use run().")

#' @rdname missingmed-defunct
#' @export
pool_sem <- function(...) .defunct_s4("pool_sem", "Use pool().")

#' @rdname missingmed-defunct
#' @export
fit_model <- function(...) {
  .defunct_s4("fit_model", "Use run(), which fits every imputation.")
}

#' @rdname missingmed-defunct
#' @export
lav_mice <- function(...) {
  .defunct_s4("lav_mice", "Use run() with engine = \"lavaan\".")
}

#' @rdname missingmed-defunct
#' @export
mx_mice <- function(...) {
  .defunct_s4("mx_mice", paste0(
    "There is no replacement: OpenMx models are no longer supported; ",
    "use engine = \"lavaan\"."
  ))
}
