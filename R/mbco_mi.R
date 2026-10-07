# D4-stacked MBCO for H0: a * b = 0 under multiple imputation.
#
# Ported from research/Missing Effect/code/prototype-d4-mbco.R (the spec-by-
# example) and generalized to the medfit mediation spec (arbitrary formulas +
# stats families). MBCO does not commute with Rubin's rules: the constrained
# log-likelihood is the *branch union* max(drop_a, drop_b), so the pooled
# estimate is insufficient and the per-imputation datasets are required.
#
# Hosting: D4-MBCO under multiple imputation lives in missingmed (author
# decision, 2026-10-07; Data-Wise/missingmed#19). RMediation keeps
# complete-data MBCO.

# Drop EVERY term whose variables include `var`, not just the main effect.
#
# stats::update(f, . ~ . - M) removes only the term labelled exactly "M", so
# `Y ~ X * M + C` keeps X:M and `Y ~ poly(M, 2) + X` is left completely
# unchanged -- in the latter case the "constrained" model equals the full model,
# T = 0, and the test can never reject. Filtering on all.vars() of each term
# label sees inside poly(M, 2), I(M^2), log(M), ns(M, 3) and X:M alike, so no
# catalog of term shapes is needed. See
# docs/specs/SPEC-mbco-constrained-models-2026-08-30.md.
.mm_drop_path <- function(formula, var) {
  tt <- stats::terms(formula)
  tl <- attr(tt, "term.labels")
  idx <- which(vapply(tl, function(t) var %in% all.vars(str2lang(t)), logical(1)))
  if (!length(idx)) {
    return(formula)
  }
  # Dropping every term: drop.terms() cannot express an empty RHS, so rebuild
  # the intercept/offset-only model by hand.
  if (length(idx) == length(tl)) {
    rhs <- if (identical(attr(tt, "intercept"), 1L)) "1" else "0"
    off <- attr(tt, "offset")
    if (length(off)) {
      rhs <- paste(c(rhs, as.character(attr(tt, "variables"))[off + 1L]),
        collapse = " + "
      )
    }
    return(stats::reformulate(rhs, response = formula[[2]]))
  }
  # drop.terms() carries the response EXPRESSION, the intercept flag and any
  # offset() through. Rebuilding from term.labels alone (via reformulate with
  # all.vars(formula)[1]) silently turned `log(Y) ~ .` into `Y ~ .`, so llF and
  # llC were computed on different scales and 2*(llF - llC) was not a
  # likelihood ratio at all; it also regained a suppressed intercept and
  # dropped offsets.
  stats::formula(stats::drop.terms(tt, idx, keep.response = TRUE))
}

# How many parameters does nulling `var` remove from `formula`? This is the
# degrees of freedom of the corresponding branch of the constraint. It is a
# difference of design RANKS, not column counts: a factor level absent from
# `data` but kept in levels() leaves an all-zero column that glm() aliases, so
# the column count overstates the parameters actually estimated. On a
# full-rank design the two coincide.
.mm_drop_df <- function(formula, var, data) {
  rank_of <- function(f) qr(stats::model.matrix(f, data = data))$rank
  rank_of(formula) - rank_of(.mm_drop_path(formula, var))
}

# RULING (2026-08-30, author): when the outcome model contains a
# treatment-by-mediator interaction, MBCO's null `a * b = 0` is read as "the
# mediator has no effect on the outcome at all" -- so nulling the b-path drops
# the mediator's main effect AND every interaction carrying it. The alternative
# reading (null the main effect only, leaving X:M) would let mediation run
# through the interaction under a hypothesis claiming there is none.
# .mm_drop_path() implements this directly; no special case is needed. See
# docs/specs/SPEC-mbco-constrained-models-2026-08-30.md section 4.

# Mediation log-likelihood: full, or with the a-path (treatment -> mediator) or
# the b-path (mediator -> outcome) dropped.
#
# NB engine: this refits with stats::glm() regardless of @engine, and carries no
# weights. That is latent rather than live -- infer(type = "mbco") errors on IPW
# fits by design, and the MI path is glm-only -- but it is a known limitation
# (SPEC-mbco-constrained-models-2026-08-30.md, section 6).
.mm_ll_med <- function(d, formula_y, formula_m, family_y, family_m,
                       treatment, mediator, drop_a = FALSE, drop_b = FALSE) {
  fm_use <- if (drop_a) .mm_drop_path(formula_m, treatment) else formula_m
  fy_use <- if (drop_b) .mm_drop_path(formula_y, mediator) else formula_y
  llm <- as.numeric(stats::logLik(stats::glm(fm_use, data = d, family = family_m)))
  lly <- as.numeric(stats::logLik(stats::glm(fy_use, data = d, family = family_y)))
  llm + lly
}

# The three MBCO log-likelihoods of one dataset: the full model and the two
# single-path nulls. Both the statistic and the branch indicator derive from
# this triple, so each dataset is fit once.
.mm_mbco_lls <- function(d, formula_y, formula_m, family_y, family_m,
                         treatment, mediator) {
  c(
    full = .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator),
    a = .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_a = TRUE),
    b = .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_b = TRUE)
  )
}

# Branch-union MBCO statistic from a log-likelihood triple. Ties go to the a = 0
# branch.
.mm_mbco_T_from_lls <- function(lls) {
  2 * (lls[["full"]] - max(lls[["a"]], lls[["b"]]))
}

# Complete-data MBCO likelihood-ratio statistic (branch-union constraint).
.mm_mbco_T <- function(d, formula_y, formula_m, family_y, family_m,
                       treatment, mediator) {
  lls <- .mm_mbco_lls(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  .mm_mbco_T_k(lls, d, formula_y, formula_m, treatment, mediator)
}

# T and its df k from a precomputed triple, k taken from the dataset's own
# winning branch.
.mm_mbco_T_k <- function(lls, d, formula_y, formula_m, treatment, mediator) {
  # NB when the max() below selects the a-branch, the OUTCOME model appears in
  # both llF and llC and cancels exactly, so T does not depend on it at all.
  # That is correct, not a bug -- but a user who edits the outcome model and
  # sees T unmoved will suspect one.
  a_wins <- lls[["a"]] >= lls[["b"]]
  # The df of the statistic is the number of parameters the WINNING branch
  # removes -- 1 in the plain specification, but more once the target appears in
  # an interaction or a nonlinear term, since nulling the path now removes all
  # of them. Hard-coding k = 1 would refer a multi-parameter constraint to
  # F(1, nu). See SPEC-mbco-constrained-models-2026-08-30.md.
  k <- if (a_wins) {
    .mm_drop_df(formula_m, treatment, d)
  } else {
    .mm_drop_df(formula_y, mediator, d)
  }
  c(T = .mm_mbco_T_from_lls(lls), k = k)
}

# D4 pooling of a likelihood-ratio statistic (Chan & Meng 2022; Grund et al.
# 2021). d_S = LRT on the stacked data / K (= LRT of the average log-lik).
.mm_d4_from_stats <- function(d_k, d_S, k = 1) {
  K <- length(d_k)
  dbar <- mean(d_k)
  r4 <- max(0, (K + 1) / (k * (K - 1)) * (dbar - d_S))
  D4 <- d_S / (k * (1 + r4))
  km1 <- k * (K - 1)
  nu <- if (km1 > 4) {
    4 + (km1 - 4) * (1 + (1 - 2 / km1) / r4)^2
  } else {
    0.5 * km1 * (1 + 1 / k) * (1 + 1 / r4)^2
  }
  c(D4 = D4, p = stats::pf(D4, k, nu, lower.tail = FALSE), r4 = r4, nu = nu, d_S = d_S)
}

# D4-stacked MBCO across a list of imputed datasets.
#
# ariv = "own" pools each imputation's statistic on its OWN winning branch
# (standard Chan & Meng r4) and refuses when the branches remove different
# numbers of parameters. ariv = "fixed" recomputes every per-imputation
# statistic on the branch the STACKED constrained fit selected, so branch
# disagreement across imputations cannot pull dbar, and hence r4, down; d_S is
# the same under both. Both null fits are run in every imputation either way,
# because the branch diagnostics (branch_mix, p_branch_a) need each
# imputation's own winner.
.mm_d4_mbco <- function(implist, formula_y, formula_m, family_y, family_m,
                        treatment, mediator, ariv = c("fixed", "own")) {
  ariv <- match.arg(ariv)
  K <- length(implist)
  if (K < 2) {
    stop("D4 pooling of the MBCO statistic needs at least 2 imputations; the ",
      "supplied object has ", K, ". Re-impute with m >= 2, or, for a single ",
      "complete dataset, use complete-data MBCO (e.g. RMediation::mbco()).",
      call. = FALSE
    )
  }
  lls_of <- function(d) {
    .mm_mbco_lls(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  }
  lls <- lapply(implist, lls_of)
  stacked <- do.call(rbind, implist)
  lls_S <- lls_of(stacked)
  a_wins <- vapply(lls, function(l) l[["a"]] >= l[["b"]], logical(1))
  stacked_a <- lls_S[["a"]] >= lls_S[["b"]]

  if (ariv == "own") {
    per <- vapply(seq_len(K), function(i) {
      .mm_mbco_T_k(lls[[i]], implist[[i]], formula_y, formula_m, treatment, mediator)
    }, numeric(2))
    d_k <- per[1L, ]
    st <- .mm_mbco_T_k(lls_S, stacked, formula_y, formula_m, treatment, mediator)
    d_S <- unname(st[["T"]]) / K
    # D4 assumes one k for the whole pooling. The branch is data-dependent, so
    # if imputations disagree about which one wins -- and therefore about how
    # many parameters the constraint removes -- there is no single k and
    # pooling is not defined. Refuse rather than pick one.
    ks <- unique(c(per[2L, ], st[["k"]]))
    if (length(ks) > 1L) {
      stop("The MBCO constraint removes a different number of parameters in ",
        "different imputations (", paste(sort(ks), collapse = " vs "), "), so the ",
        "D4 reference distribution is not well defined. This happens when the ",
        "winning branch of `max(a = 0, b = 0)` differs across imputations and the ",
        "two paths carry different numbers of terms, or when a factor level that ",
        "interacts with the treatment or mediator is absent from some imputations.",
        call. = FALSE
      )
    }
    k <- ks[[1L]]
  } else {
    key <- if (stacked_a) "a" else "b"
    d_k <- vapply(lls, function(l) 2 * (l[["full"]] - l[[key]]), numeric(1))
    d_S <- unname(.mm_mbco_T_from_lls(lls_S)) / K
    # Every imputation is tested on the stacked branch, so k is the stacked
    # fit's. That is only one k if the branch removes the same number of
    # parameters in every imputation. Equal design ranks are NOT required: a
    # factor level absent from one imputation lowers the full and the nulled
    # rank alike when the factor enters as a main effect, leaving k unchanged.
    # k differs only when the sparse level interacts with the nulled path.
    f_br <- if (stacked_a) formula_m else formula_y
    v_br <- if (stacked_a) treatment else mediator
    k_S <- .mm_drop_df(f_br, v_br, stacked)
    for (i in seq_len(K)) {
      k_i <- .mm_drop_df(f_br, v_br, implist[[i]])
      if (k_i != k_S) {
        stop("Under ariv = \"fixed\", the ", key, " = 0 constraint removes ",
          k_i, " parameter", if (k_i == 1) "" else "s", " from the ",
          if (stacked_a) "mediator" else "outcome", " model in imputation ", i,
          " but ", k_S, " in the stacked data, so there is no single k for the ",
          "D4 reference distribution. This happens, for example, when a level of ",
          "a factor that interacts with the ", if (stacked_a) "treatment" else "mediator",
          " is absent from that imputation; drop or merge the sparse level.",
          call. = FALSE
        )
      }
    }
    k <- as.numeric(k_S)
  }

  MbcoMIResult(
    .mm_d4_from_stats(d_k, d_S, k = k),
    ariv = ariv, k = k, m = K,
    stacked_branch = if (stacked_a) "a" else "b",
    branch_mix = length(unique(a_wins)) > 1L,
    p_branch_a = mean(a_wins)
  )
}

#' D4-stacked MBCO test of an indirect effect across imputed datasets
#'
#' Tests \eqn{H_0: a b = 0} with the model-based constrained optimization (MBCO)
#' likelihood-ratio statistic, pooled across multiply imputed datasets with the
#' D4 rule (Chan & Meng, 2022; Grund, Lüdtke & Robitzsch, 2021). This is the
#' engine behind `infer(<MDMediationFit>, type = "mbco")`, exported so that
#' other packages can call it on a plain list of completed datasets.
#'
#' The MBCO constraint is a branch union, \eqn{\max(\ell_{a=0}, \ell_{b=0})},
#' and nulling a path drops every term that carries it (for example both `M`
#' and `X:M` from `Y ~ X * M`). The D4 statistic is
#' \eqn{D_4 = d_S / (k (1 + r_4))}, referred to \eqn{F(k, \nu)}, where
#' \eqn{d_S} is the statistic on the stacked data divided by \eqn{K} and
#' \eqn{r_4} is the relative increase in variance estimated from the
#' per-imputation statistics. `ariv` chooses how those statistics are formed:
#'
#' * `"fixed"` (default): each imputation's statistic is computed on the branch
#'   (`a = 0` or `b = 0`) that the **stacked** constrained fit selected.
#'   Imputations that disagree on the winning branch then cannot pull
#'   \eqn{r_4} down, and every imputation uses the stacked fit's `k`. An error
#'   is raised if that branch's constraint removes a different number of
#'   parameters in some imputation than in the stacked data (for example, a
#'   level of a factor that interacts with the treatment or mediator is absent
#'   from one imputation). `k` is a difference of design-matrix ranks, so a
#'   sparse level of a main-effect factor does not trigger it.
#' * `"own"`: each imputation's statistic is computed on its own winning branch
#'   (the standard Chan & Meng \eqn{r_4}). This reproduces missingmed 0.4.0.
#'   It errors when the winning branches remove different numbers of
#'   parameters, since there is then no single `k`.
#'
#' **Cost.** Every imputation is fit three times (the full model and both
#' single-path nulls), plus the same three fits on the stacked data. The
#' `ariv = "fixed"` statistic alone needs only the null on the stacked branch;
#' the second null per imputation is what the branch diagnostics
#' `branch_mix` and `p_branch_a` require.
#'
#' At least two imputations are required. For a single complete dataset, use a
#' complete-data MBCO test such as [RMediation::mbco()].
#'
#' @param implist A list of at least two completed data frames, e.g.
#'   `mice::complete(imp, "all")`.
#' @param formula_y,formula_m Outcome and mediator model formulas.
#' @param family_y,family_m [stats::family()] objects for the two models
#'   (default [stats::gaussian()]); models are fit with [stats::glm()].
#' @param treatment,mediator Names of the treatment and mediator variables.
#' @param ariv `"fixed"` (default) or `"own"`; see Details.
#' @return An [MbcoMIResult]: the named numeric `c(D4, p, r4, nu, d_S)` with
#'   the branch diagnostics as properties.
#' @references
#' Chan, K. W., & Meng, X.-L. (2022). Multiple improvements of multiple
#' imputation likelihood ratio tests. *Statistica Sinica*.
#'
#' Grund, S., Lüdtke, O., & Robitzsch, A. (2021). Pooling methods for
#' likelihood-ratio tests with multiply imputed data. *Psychological Methods*.
#' @seealso [infer()], [MbcoMIResult]
#' @examples
#' set.seed(1)
#' implist <- lapply(1:3, function(i) {
#'   n <- 200
#'   X <- rnorm(n)
#'   M <- 0.4 * X + rnorm(n)
#'   data.frame(X = X, M = M, Y = 0.3 * M + rnorm(n))
#' })
#' mbco_d4(implist, Y ~ X + M, M ~ X,
#'   treatment = "X", mediator = "M", ariv = "fixed"
#' )
#' @export
mbco_d4 <- function(implist, formula_y, formula_m,
                    family_y = stats::gaussian(), family_m = stats::gaussian(),
                    treatment, mediator, ariv = c("fixed", "own")) {
  ariv <- match.arg(ariv)
  if (!is.list(implist) || is.data.frame(implist) ||
    !all(vapply(implist, is.data.frame, logical(1)))) {
    stop("`implist` must be a list of data frames (one per imputation), e.g. ",
      "mice::complete(imp, \"all\").",
      call. = FALSE
    )
  }
  for (nm in c("formula_y", "formula_m")) {
    if (!inherits(get(nm), "formula") || length(get(nm)) != 3L) {
      stop("`", nm, "` must be a two-sided formula.", call. = FALSE)
    }
  }
  for (nm in c("treatment", "mediator")) {
    v <- get(nm)
    if (!is.character(v) || length(v) != 1L || is.na(v)) {
      stop("`", nm, "` must be a single variable name.", call. = FALSE)
    }
  }
  if (!treatment %in% all.vars(formula_m[[3]])) {
    stop("`treatment` '", treatment, "' is not a predictor in `formula_m`.",
      call. = FALSE
    )
  }
  if (!mediator %in% all.vars(formula_y[[3]])) {
    stop("`mediator` '", mediator, "' is not a predictor in `formula_y`.",
      call. = FALSE
    )
  }
  .mm_d4_mbco(unname(implist), formula_y, formula_m, family_y, family_m,
    treatment, mediator, ariv = ariv
  )
}
