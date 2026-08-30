# D4-stacked MBCO for H0: a * b = 0 under multiple imputation.
#
# Ported from research/Missing Effect/code/prototype-d4-mbco.R (the spec-by-
# example) and generalized to the medfit mediation spec (arbitrary formulas +
# stats families). MBCO does not commute with Rubin's rules: the constrained
# log-likelihood is the *branch union* max(drop_a, drop_b), so the pooled
# estimate is insufficient and the per-imputation datasets are required.
#
# TODO(rmediation): this D4 machinery is hosted in missingmed as an interim
# measure. RMediation::mbco() is currently OpenMx-only; once it gains an
# MI/per-imputation entry point, move this there and delegate.

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
# degrees of freedom of the corresponding branch of the constraint.
.mm_drop_df <- function(formula, var, data) {
  full <- ncol(stats::model.matrix(formula, data = data))
  full - ncol(stats::model.matrix(.mm_drop_path(formula, var), data = data))
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

# Complete-data MBCO likelihood-ratio statistic (branch-union constraint).
.mm_mbco_T <- function(d, formula_y, formula_m, family_y, family_m,
                       treatment, mediator) {
  # NB when the max() below selects the a-branch, the OUTCOME model appears in
  # both llF and llC and cancels exactly, so T does not depend on it at all.
  # That is correct, not a bug -- but a user who edits the outcome model and
  # sees T unmoved will suspect one.
  llF <- .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  ll_a <- .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_a = TRUE)
  ll_b <- .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_b = TRUE)
  a_wins <- ll_a >= ll_b
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
  c(T = 2 * (llF - max(ll_a, ll_b)), k = k)
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
.mm_d4_mbco <- function(implist, formula_y, formula_m, family_y, family_m,
                        treatment, mediator) {
  K <- length(implist)
  if (K < 2) {
    stop("D4 pooling of the MBCO statistic needs at least 2 imputations; the ",
      "supplied object has ", K, ". Re-impute with m >= 2.",
      call. = FALSE
    )
  }
  per <- vapply(implist, function(d) {
    .mm_mbco_T(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  }, numeric(2))
  d_k <- per["T", ]
  stacked <- do.call(rbind, implist)
  st <- .mm_mbco_T(stacked, formula_y, formula_m, family_y, family_m, treatment, mediator)
  d_S <- unname(st[["T"]]) / K
  # D4 assumes one k for the whole pooling. The branch is data-dependent, so if
  # imputations disagree about which one wins -- and therefore about how many
  # parameters the constraint removes -- there is no single k and pooling is not
  # defined. Refuse rather than pick one.
  ks <- unique(c(per["k", ], st[["k"]]))
  if (length(ks) > 1L) {
    stop("The MBCO constraint removes a different number of parameters in ",
      "different imputations (", paste(sort(ks), collapse = " vs "), "), so the ",
      "D4 reference distribution is not well defined. This happens when the ",
      "winning branch of `max(a = 0, b = 0)` differs across imputations and the ",
      "two paths carry different numbers of terms.",
      call. = FALSE
    )
  }
  .mm_d4_from_stats(d_k, d_S, k = ks[[1L]])
}
