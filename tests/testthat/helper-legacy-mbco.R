# The pre-#19 (missingmed 0.4.0) MBCO driver, copied verbatim from
# R/mbco_mi.R at ff64297 with only the names changed (.mm_* -> legacy_* and
# missingmed::: on the unchanged helpers). test-mbco-ariv.R checks that
# infer(type = "mbco", ariv = "own") is bit-identical to this, computed in the
# same session, so the check does not depend on platform floating point.

# Complete-data MBCO likelihood-ratio statistic (branch-union constraint).
legacy_mbco_T <- function(d, formula_y, formula_m, family_y, family_m,
                       treatment, mediator) {
  # NB when the max() below selects the a-branch, the OUTCOME model appears in
  # both llF and llC and cancels exactly, so T does not depend on it at all.
  # That is correct, not a bug -- but a user who edits the outcome model and
  # sees T unmoved will suspect one.
  llF <- missingmed:::.mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  ll_a <- missingmed:::.mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_a = TRUE)
  ll_b <- missingmed:::.mm_ll_med(d, formula_y, formula_m, family_y, family_m, treatment, mediator, drop_b = TRUE)
  a_wins <- ll_a >= ll_b
  # The df of the statistic is the number of parameters the WINNING branch
  # removes -- 1 in the plain specification, but more once the target appears in
  # an interaction or a nonlinear term, since nulling the path now removes all
  # of them. Hard-coding k = 1 would refer a multi-parameter constraint to
  # F(1, nu). See SPEC-mbco-constrained-models-2026-08-30.md.
  k <- if (a_wins) {
    missingmed:::.mm_drop_df(formula_m, treatment, d)
  } else {
    missingmed:::.mm_drop_df(formula_y, mediator, d)
  }
  c(T = 2 * (llF - max(ll_a, ll_b)), k = k)
}
# D4-stacked MBCO across a list of imputed datasets.
legacy_d4_mbco <- function(implist, formula_y, formula_m, family_y, family_m,
                        treatment, mediator) {
  K <- length(implist)
  if (K < 2) {
    stop("D4 pooling of the MBCO statistic needs at least 2 imputations; the ",
      "supplied object has ", K, ". Re-impute with m >= 2.",
      call. = FALSE
    )
  }
  per <- vapply(implist, function(d) {
    legacy_mbco_T(d, formula_y, formula_m, family_y, family_m, treatment, mediator)
  }, numeric(2))
  d_k <- per["T", ]
  stacked <- do.call(rbind, implist)
  st <- legacy_mbco_T(stacked, formula_y, formula_m, family_y, family_m, treatment, mediator)
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
  missingmed:::.mm_d4_from_stats(d_k, d_S, k = ks[[1L]])
}
