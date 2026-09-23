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
#' The returned tidy table also carries a per-coefficient Wald test
#' (`statistic`, `df`, `riv`, `fmi`, `p_value`); see [MDMediationResult] for the
#' columns and why they do not test the indirect effect.
#'
#' @references Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in
#'   Surveys*. Wiley.
#'
#'   Barnard, J., & Rubin, D. B. (1999). Small-sample degrees of freedom with
#'   multiple imputation. *Biometrika*, 86(4), 948--955.
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
  # Everything not overwritten above is still imputation 1's. Carrying one
  # imputation's completed data and residual SDs on an object labelled "pooled"
  # invites them to be read as pooled quantities, which they are not: with m = 3
  # here, sigma_m differed by 2% across imputations. There is no single completed
  # dataset for a pooled fit, and this package does not claim to pool nuisance
  # parameters (averaging sigma-hat is not pooling sigma-hat-squared, and neither
  # is the Rubin estimate), so carry nothing rather than something misread.
  # NULL, not NA: medfit's validator does an unguarded `sigma_m < 0`, and its
  # data/n_obs consistency check forbids a zero-row frame.
  pooled@data <- NULL
  pooled@sigma_m <- NULL
  pooled@sigma_y <- NULL
  # @n_obs is deliberately NOT blanked: mice::complete() returns full-n frames,
  # so it is identical across imputations and imputation 1's value is correct.
  pooled@converged <- all(vapply(
    object@per_imputation, function(x) isTRUE(x@converged), logical(1)
  ))

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
  tidy_table <- cbind(tidy_table, .pool_wald(
    tidy_table, m = m, fit = object@per_imputation[[1]]
  ))

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

# Per-term Rubin inference for the pooled tidy table: statistic, df, riv, fmi,
# p_value (docs/specs/SPEC-pooled-inference-columns-2026-09-23.md).
#
# df is Barnard & Rubin (1999), written as mice:::barnard.rubin() writes it (no
# Inf/Inf when B = 0). The complete-data df is per model: n_obs minus that
# model's coefficient count, read off the m_* / y_* prefixes of the estimates,
# which include the intercept. A binomial or poisson model has dfcom = Inf,
# since summary.glm() uses z-tests there; with Inf, df reduces to Rubin (1987).
# The alias rows a, b and c_prime take their source model's dfcom, so each
# equals its m_X / y_M / y_X row. At m = 1 there is no between-imputation
# variance to learn from: riv = fmi = 0 and df = dfcom, the single-fit Wald test.
#
# These are per-path Wald quantities, not a test of the indirect effect.
.pool_wald <- function(tidy_table, m, fit) {
  term <- tidy_table$term
  n <- fit@n_obs
  dfcom_of <- function(prefix, family) {
    fam <- if (is.null(family)) "gaussian" else family$family
    if (fam %in% c("binomial", "poisson")) Inf else n - sum(startsWith(term, prefix))
  }
  dfcom_m <- dfcom_of("m_", fit@family_m)
  dfcom_y <- dfcom_of("y_", fit@family_y)
  # Terms outside both models' prefixes and the three aliases get the smaller
  # complete-data df, the conservative choice.
  dfcom <- ifelse(startsWith(term, "m_") | term == "a", dfcom_m,
    ifelse(startsWith(term, "y_") | term %in% c("b", "c_prime"), dfcom_y,
      min(dfcom_m, dfcom_y)
    )
  )

  statistic <- tidy_table$estimate / tidy_table$std_error
  if (m == 1) {
    riv <- fmi <- rep(0, length(term))
    df <- dfcom
  } else {
    riv <- (1 + 1 / m) * tidy_table$var_b / tidy_table$var_w
    lambda <- (1 + 1 / m) * tidy_table$var_b / tidy_table$var_tot
    tmp <- (1 - lambda) * (1 + dfcom) * dfcom
    df <- ifelse(is.infinite(dfcom), (m - 1) / lambda^2,
      (m - 1) * tmp / ((dfcom + 3) * (m - 1) + lambda^2 * tmp)
    )
    fmi <- (riv + 2 / (df + 3)) / (riv + 1)
  }
  p_value <- ifelse(is.infinite(df), 2 * stats::pnorm(-abs(statistic)),
    2 * stats::pt(-abs(statistic), df)
  )
  data.frame(statistic = statistic, df = df, riv = riv, fmi = fmi, p_value = p_value)
}
