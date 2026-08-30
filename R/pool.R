#' Pool per-imputation mediation fits with Rubin's rules
#'
#' Applies Rubin's (1987) rules to the list of per-imputation **named**
#' [medfit::MediationData] objects in an [MDMediationFit], producing a single
#' pooled named [medfit::MediationData] (the `pooled` slot of the returned
#' [MDMediationResult]). Because the estimates and variance-covariance carry the
#' mediation path names (`a`, `b`, `c_prime`, ...), the pooled object is valid
#' input to [RMediation::ci_mediation_data()] / [RMediation::medci()].
#'
#' Pooling math (migrated from the S4 `pool_sem` / `pool_tidy` / `pool_cov`):
#' \deqn{\bar Q = \frac{1}{m}\sum_i Q_i, \quad \bar U = \frac{1}{m}\sum_i U_i,
#'   \quad B = \mathrm{cov}(Q_1, \ldots, Q_m), \quad T = \bar U + (1 + 1/m) B.}
#'
#' It is the S7 successor of the S4 [pool_sem()] method.
#'
#' @param object An [MDMediationFit] object. Anything else (a `mice::mira`,
#'   say) is forwarded to [mice::pool()].
#' @param ... Unused.
#' @return An [MDMediationResult] object.
#' @seealso [run()], [infer()], [pool_sem()]
#' @references Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in
#'   Surveys*. Wiley.
#' @export
#' @name pool
pool <- S7::new_generic("pool", "object")

# Anything that is not a missingmed fit (a mice::mira, for one) goes to
# mice::pool, so attaching missingmed does not break the standard mice workflow.
S7::method(pool, S7::class_any) <- function(object, ...) {
  mice::pool(object, ...)
}

S7::method(pool, MDMediationData) <- function(object, ...) {
  stop("`pool()` takes a fitted object. Call `run()` on this data first.",
    call. = FALSE
  )
}

S7::method(pool, MDMediationResult) <- function(object, ...) {
  stop("This object is already pooled. Pass it to `infer()`.", call. = FALSE)
}

S7::method(pool, MDMediationFit) <- function(object, ...) {
  m <- object@m
  if (m < 1) stop("Nothing to pool: @m must be >= 1.", call. = FALSE)

  est_list <- lapply(object@per_imputation, function(x) x@estimates)
  vcov_list <- lapply(object@per_imputation, function(x) x@vcov)
  nms <- names(est_list[[1]])

  # Stack estimates: m x p (one row per imputation)
  Qmat <- do.call(rbind, est_list)
  colnames(Qmat) <- nms
  Qbar <- colMeans(Qmat)
  names(Qbar) <- nms

  # Rubin's variance decomposition
  Ubar <- Reduce(`+`, vcov_list) / m # within-imputation
  if (m > 1) {
    B <- stats::cov(Qmat) # between-imputation
  } else {
    B <- matrix(0, length(nms), length(nms))
  }
  dimnames(B) <- list(nms, nms)
  Tmat <- Ubar + (1 + 1 / m) * B # total
  dimnames(Tmat) <- list(nms, nms)

  # Build the pooled MediationData by copy-modifying a per-imputation template
  pooled <- object@per_imputation[[1]]
  pooled@estimates <- Qbar
  pooled@vcov <- Tmat
  pooled@a_path <- unname(Qbar[["a"]])
  pooled@b_path <- unname(Qbar[["b"]])
  pooled@c_prime <- unname(Qbar[["c_prime"]])

  # Pooled tidy table (diagonal variance components, Rubin)
  tidy_table <- data.frame(
    term = nms,
    estimate = unname(Qbar),
    std_error = sqrt(diag(Tmat)),
    var_w = diag(Ubar),
    var_b = diag(B),
    var_tot = diag(Tmat),
    row.names = NULL,
    stringsAsFactors = FALSE
  )

  MDMediationResult(
    pooled = pooled,
    tidy_table = tidy_table,
    cov_total = Tmat,
    cov_between = B,
    cov_within = Ubar,
    m = m,
    engine = object@engine,
    conf_int = object@conf_int,
    conf_level = object@conf_level
  )
}
