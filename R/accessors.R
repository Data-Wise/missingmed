#' Access the per-imputation mediation fits (for MBCO)
#'
#' Returns the list of per-imputation **named** [medfit::MediationData] objects
#' held in an [MDMediationFit], together with the number of imputations `m`.
#'
#' This accessor exists because **MBCO does not commute with Rubin's rules**:
#' D4-stacked MBCO needs the per-imputation fits, not the pooled estimate. The
#' list it returns is the shape consumed by [infer()]`(type = "mbco")` and by an
#' external [RMediation::mbco()] MI entry point (missingmed issue #2).
#'
#' @param object An [MDMediationFit] object.
#' @param ... Unused.
#' @return A list with components `per_imputation` (a length-`m` list of named
#'   [medfit::MediationData]) and `m` (the number of imputations).
#' @seealso [run()], [infer()]
#' @examples
#' set.seed(1)
#' n <- 150
#' d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
#' d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
#' d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
#' d$M[sample(n, 25)] <- NA
#' imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
#' md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
#'   treatment = "X", mediator = "M"
#' )
#' fit <- run(md)
#' pl <- per_imputation_list(fit)
#' pl$m
#' # The a path in each imputation, before pooling
#' vapply(pl$per_imputation, function(x) x@a_path, numeric(1))
#' @export
#' @name per_imputation_list
per_imputation_list <- S7::new_generic("per_imputation_list", "object")

S7::method(per_imputation_list, MDMediationFit) <- function(object) {
  list(per_imputation = object@per_imputation, m = object@m)
}

#' Number of imputations
#'
#' @param object An [MDMediationFit] or [MDMediationResult] object.
#' @param ... Unused.
#' @return Integer count of imputations.
#' @examples
#' set.seed(1)
#' n <- 150
#' d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
#' d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
#' d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
#' d$M[sample(n, 25)] <- NA
#' imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
#' md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
#'   treatment = "X", mediator = "M"
#' )
#' fit <- run(md)
#' n_imputations(fit)
#' n_imputations(pool(fit))
#' @export
#' @name n_imputations
n_imputations <- S7::new_generic("n_imputations", "object")

S7::method(n_imputations, MDMediationFit) <- function(object) object@m
S7::method(n_imputations, MDMediationResult) <- function(object) object@m

#' Get the number of imputations from a mids object
#'
#' Returns the number of imputations `m` stored in a [mice::mids] object.
#'
#' @param x A [mice::mids] object.
#' @return An integer: the number of imputations.
#' @examples
#' imp <- mice::mice(mice::nhanes, m = 3, printFlag = FALSE, seed = 1)
#' n_imp(imp)
#' @export
n_imp <- function(x) {
  if (!inherits(x, "mids")) {
    stop("The provided object is not a 'mids' object (it has class '",
      class(x)[1], "').",
      call. = FALSE
    )
  }
  x$m
}
