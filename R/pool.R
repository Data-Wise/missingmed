#' Pool per-imputation mediation fits with Rubin's rules
#'
#' Applies Rubin's (1987) rules to the list of per-imputation **named**
#' [medfit::MediationData] objects in an [MDMediationFit], producing a single
#' pooled named [medfit::MediationData] (the `pooled` slot of the returned
#' [MDMediationResult]). Because the estimates and variance-covariance carry the
#' mediation path names (`a`, `b`, `c_prime`, ...), the pooled object is valid
#' input to [RMediation::ci_mediation_data()] / [RMediation::medci()].
#' For a model with a treatment-by-mediator interaction, use
#' [infer()]`(type = "mc", treatment_level = )` instead: those RMediation
#' functions use only \eqn{a b}, the indirect effect at treatment level 0.
#'
#' Pooling math (migrated from the S4 `pool_sem` / `pool_tidy` / `pool_cov`):
#' \deqn{\bar Q = \frac{1}{m}\sum_i Q_i, \quad \bar U = \frac{1}{m}\sum_i U_i,
#'   \quad B = \mathrm{cov}(Q_1, \ldots, Q_m), \quad T = \bar U + (1 + 1/m) B.}
#'
#' It is the S7 successor of the S4 `pool_sem()` method.
#'
#' @param object An [MDMediationFit] object. Anything else (a `mice::mira`,
#'   say) is forwarded to [mice::pool()].
#' @param ... Unused.
#' @return An [MDMediationResult] object.
#' @seealso [run()], [infer()]
#' @details
#' The returned tidy table also carries a per-coefficient Wald test
#' (`statistic`, `df`, `riv`, `fmi`, `p_value`) and, when `conf_int = TRUE` was
#' set in [set_md_mediation()], per-coefficient `conf_low` and `conf_high` at
#' `conf_level` on the same t reference; see [MDMediationResult] for the columns
#' and why they do not test or bound the indirect effect.
#'
#' @references Rubin, D. B. (1987). *Multiple Imputation for Nonresponse in
#'   Surveys*. Wiley.
#'
#'   Barnard, J., & Rubin, D. B. (1999). Small-sample degrees of freedom with
#'   multiple imputation. *Biometrika*, 86(4), 948--955.
#' @examples
#' set.seed(1)
#' n <- 150
#' d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
#' d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
#' d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
#' d$M[sample(n, 25)] <- NA
#' imp <- mice::mice(d, m = 3, method = "norm", printFlag = FALSE, seed = 1)
#' md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, conf_int = TRUE,
#'   treatment = "X", mediator = "M"
#' )
#' res <- pool(run(md))
#' res
#' # Per-coefficient table, with Rubin's df and conf_low/conf_high
#' res@tidy_table[, c("term", "estimate", "std_error", "df", "conf_low", "conf_high")]
#' @export
#' @name pool
pool <- S7::new_generic("pool", "object")

# Anything that is not a missingmed fit (a mice::mira, for one) goes to
# mice::pool, so attaching missingmed does not break the standard mice workflow.
S7::method(pool, S7::class_any) <- function(object, ...) {
  # Neither is a mice input, and mice::pool() fails on both with an error about
  # columns or lists that does not say what was expected.
  if (is.null(object) || is.data.frame(object)) {
    stop("`pool()` takes the MDMediationFit returned by `run()` (or a ",
      "mice::mira, which it passes to mice::pool()), not ",
      if (is.null(object)) "NULL" else "a data.frame", ".",
      call. = FALSE
    )
  }
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

  aligned <- .align_imputations(object@per_imputation)
  est_list <- lapply(aligned, `[[`, "est")
  vcov_list <- lapply(aligned, `[[`, "vcov")
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

  # Build the pooled MediationData by copy-modifying a per-imputation template.
  # The path properties go in with one props<- call, because S7 validates after
  # every @<- and medfit::InteractionMediationData ties them together
  # (int_med == interaction * a_path, ...): setting a_path alone leaves a
  # half-updated object that fails validation (#20).
  pooled <- object@per_imputation[[1]]
  new_props <- list(
    estimates = Qbar,
    vcov = Tmat,
    a_path = unname(Qbar[["a"]]),
    b_path = unname(Qbar[["b"]]),
    c_prime = unname(Qbar[["c_prime"]])
  )
  if (S7::S7_inherits(pooled, medfit::InteractionMediationData)) {
    new_props <- c(new_props, .pool_interaction_effects(object, Qbar))
  }
  S7::props(pooled) <- new_props
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
  if (isTRUE(object@conf_int)) {
    tidy_table <- .pool_conf_int(tidy_table, object@conf_level)
  }

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

# Per-imputation estimates and vcov, in imputation 1's coefficient order.
# Pooling stacks them by position, so an imputation whose coefficients come in
# another order would be averaged term against the wrong term without any
# error; it is reordered by name. One with a different set of coefficients
# cannot be pooled at all.
.align_imputations <- function(fits) {
  nms <- names(fits[[1]]@estimates)
  lapply(seq_along(fits), function(i) {
    e <- fits[[i]]@estimates
    v <- fits[[i]]@vcov
    if (identical(names(e), nms)) {
      return(list(est = e, vcov = v))
    }
    if (length(e) != length(nms) || !setequal(names(e), nms)) {
      only <- function(x, y) paste(setdiff(x, y), collapse = ", ")
      stop("Cannot pool: imputation ", i, " estimates different coefficients ",
        "from imputation 1 (only in imputation 1: ", only(nms, names(e)),
        "; only in imputation ", i, ": ", only(names(e), nms), "). This ",
        "happens when a factor level or a term is absent from one completed ",
        "dataset.",
        call. = FALSE
      )
    }
    if (!setequal(rownames(v), nms) || !setequal(colnames(v), nms)) {
      stop("Cannot pool: imputation ", i, " lists its coefficients in another ",
        "order, and its covariance matrix has no matching names to reorder by.",
        call. = FALSE
      )
    }
    list(est = e[nms], vcov = v[nms, nms, drop = FALSE])
  })
}

# Four-way decomposition (VanderWeele 2014) for a pooled X:M fit, in the form
# medfit's InteractionMediationData validator checks. Every component is
# recomputed from one pooled reference profile, so the identities (pie = a b,
# int_med = theta3 a, nde = cde + int_ref, ...) hold exactly and no component
# mixes quantities from different imputations:
#
# * the path coefficients a, b, c_prime and theta3 are the Rubin estimates;
# * m_star, the mediator level at which the CDE is evaluated, must be the same
#   in every imputation (it is a fixed choice, medfit's default 0);
# * m_ref = b0 + sum_k beta_k * mean(C_k), the mediator's expected value at
#   the reference treatment level with covariates at their means, depends on
#   each completed dataset when a covariate is imputed. It is pooled as the
#   mean of the per-imputation values (read back from medfit's own int_ref;
#   see .interaction_m_ref()), and int_ref = theta3 (m_ref - m_star) uses the
#   pooled theta3.
.pool_interaction_effects <- function(object, Qbar) {
  fits <- object@per_imputation
  a <- unname(Qbar[["a"]])
  b <- unname(Qbar[["b"]])
  c_prime <- unname(Qbar[["c_prime"]])
  theta3 <- unname(Qbar[["theta3"]])
  m_stars <- vapply(fits, function(x) x@m_star, numeric(1))
  if (any(abs(m_stars - m_stars[[1]]) > 1e-12)) {
    stop("The imputations were fitted at different mediator reference levels ",
      "(m_star: ", paste(unique(signif(m_stars, 6)), collapse = ", "), "), so ",
      "their interaction decompositions cannot be pooled.", call. = FALSE)
  }
  m_star <- m_stars[[1]]
  m_ref <- mean(vapply(fits, .interaction_m_ref, numeric(1)))
  cde <- c_prime + theta3 * m_star
  int_ref <- theta3 * (m_ref - m_star)
  int_med <- theta3 * a
  pie <- a * b
  list(
    interaction = theta3, cde = cde, int_ref = int_ref, int_med = int_med,
    pie = pie, nde = cde + int_ref, nie = int_med + pie,
    total_effect = cde + int_ref + int_med + pie
  )
}

# m_ref for one per-imputation InteractionMediationData: the mediator's
# expected value at the reference treatment level with covariates at their
# means. medfit defines int_ref = theta3 (m_ref - m_star), so m_ref is read
# back from medfit's own int_ref, which works whatever medfit version computed
# it. Only an exactly zero theta3 hides m_ref; then it is rebuilt from the
# m_-prefixed estimates and the covariate means medfit (>= 0.4.0) stores on
# @data, and int_ref is 0 in that imputation either way.
.interaction_m_ref <- function(fit) {
  if (fit@interaction != 0) {
    return(fit@m_star + fit@int_ref / fit@interaction)
  }
  est <- fit@estimates
  m_terms <- sub("^m_", "", grep("^m_", names(est), value = TRUE))
  covs <- setdiff(m_terms, c("(Intercept)", fit@treatment))
  cbar <- attr(fit@data, "medfit_covariate_means")
  if (length(covs) > 0L && !all(covs %in% names(cbar))) {
    stop("Cannot pool the interaction decomposition: an imputation has an ",
      "interaction estimate of exactly 0, and its fit does not carry the ",
      "covariate means needed to recover the mediator's reference value. ",
      "Update medfit (>= 0.4.0).", call. = FALSE)
  }
  m_ref <- est[["b0"]]
  for (v in covs) m_ref <- m_ref + est[[paste0("m_", v)]] * cbar[[v]]
  unname(m_ref)
}

# Per-coefficient interval at `level` on the Rubin t reference already in the
# table (qt() with df = Inf is the normal quantile). Like the Wald columns,
# these bound single coefficients, not the indirect effect: use infer().
.pool_conf_int <- function(tidy_table, level) {
  q <- stats::qt(1 - (1 - level) / 2, tidy_table$df)
  tidy_table$conf_low <- tidy_table$estimate - q * tidy_table$std_error
  tidy_table$conf_high <- tidy_table$estimate + q * tidy_table$std_error
  tidy_table
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
# equals its m_X / y_M / y_X row; so do an X:M fit's theta3 (y_X:M) and b0
# (m_(Intercept)). At m = 1 there is no between-imputation
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
  # medfit::InteractionMediationData has no family properties (medfit fits
  # X:M models with lm only), so a missing property reads as gaussian.
  family_of <- function(nm) if (nm %in% S7::prop_names(fit)) S7::prop(fit, nm)
  dfcom_m <- dfcom_of("m_", family_of("family_m"))
  dfcom_y <- dfcom_of("y_", family_of("family_y"))
  # Terms outside both models' prefixes and the three aliases get the smaller
  # complete-data df, the conservative choice.
  lav <- identical(fit@source_package, "lavaan")
  dfcom <- ifelse(startsWith(term, "m_") | term %in% c("a", "b0"), dfcom_m,
    ifelse(startsWith(term, "y_") | term %in% c("b", "c_prime", "theta3"), dfcom_y,
      min(dfcom_m, dfcom_y)
    )
  )

  # lavaan names its parameters (M~C, Y~~Y, user labels), so the m_/y_ prefix
  # rule does not apply. Its tests are z-tests: the complete-data df is Inf.
  if (lav) dfcom <- rep(Inf, length(term))

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
  # A variance (`M~~M`: both sides the same variable) is tested against a
  # boundary null (variance = 0), where a Wald z-test is not valid: keep the
  # estimate and SE, leave the test NA. A covariance between two different
  # variables (`Y~~Y2`) has an interior null, so its test is kept.
  if (lav) {
    sides <- strsplit(term, "~~", fixed = TRUE)
    vv <- vapply(sides, function(p) length(p) == 2L && identical(p[1L], p[2L]),
      logical(1))
    statistic[vv] <- NA_real_
    p_value[vv] <- NA_real_
  }
  data.frame(statistic = statistic, df = df, riv = riv, fmi = fmi, p_value = p_value)
}
