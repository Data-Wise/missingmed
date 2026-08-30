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
  tl <- attr(stats::terms(formula), "term.labels")
  keep <- tl[!vapply(tl, function(t) var %in% all.vars(str2lang(t)), logical(1))]
  stats::reformulate(if (length(keep)) keep else "1",
    response = all.vars(formula)[1]
  )
}

# Terms carrying BOTH the treatment and the mediator (an exposure-mediator
# interaction). Their presence makes "the b-path is zero" ambiguous -- see
# .mm_check_no_xm_interaction().
.mm_xm_terms <- function(formula_y, treatment, mediator) {
  tl <- attr(stats::terms(formula_y), "term.labels")
  tl[vapply(tl, function(t) {
    v <- all.vars(str2lang(t))
    treatment %in% v && mediator %in% v
  }, logical(1))]
}

# With an exposure-mediator interaction the indirect effect is not a * b (the
# natural indirect effect involves the interaction too), so "b = 0" has more
# than one defensible reading and MBCO as published (Tofighi & Kelley 2020) is
# stated for the no-interaction case. Refuse rather than silently pick one.
.mm_check_no_xm_interaction <- function(formula_y, treatment, mediator) {
  bad <- .mm_xm_terms(formula_y, treatment, mediator)
  if (length(bad)) {
    stop("MBCO is not defined here: the outcome model contains a ",
      "treatment-by-mediator interaction (", paste(bad, collapse = ", "), "). ",
      "With that interaction the indirect effect is not `a * b`, so the null ",
      "`a * b = 0` has no single meaning -- nulling the mediator's main effect ",
      "alone would leave mediation running through the interaction. Fit MBCO ",
      "on a model without the interaction, or use `infer(type = \"mc\")`.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

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
  .mm_check_no_xm_interaction(formula_y, treatment, mediator)
  # NB when the max() below selects the a-branch, the OUTCOME model appears in
  # both llF and llC and cancels exactly, so T does not depend on it at all.
  # That is correct, not a bug -- but a user who edits the outcome model and
  # sees T unmoved will suspect one.
  llF <- .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  llC <- max(
    .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_a = TRUE),
    .mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_b = TRUE)
  )
  2 * (llF - llC)
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
  d_k <- vapply(implist, function(d) {
    .mm_mbco_T(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  }, numeric(1))
  stacked <- do.call(rbind, implist)
  d_S <- .mm_mbco_T(stacked, formula_y, formula_m, family_y, family_m, treatment, mediator) / K
  .mm_d4_from_stats(d_k, d_S, k = 1)
}
