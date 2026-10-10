# Variance of the IPW regression coefficients that accounts for estimating the
# weights. Design: docs/specs/NOTE-ipw-weight-score-stacking-2026-10-09.md.
# Not yet wired into run(); steps 2-3 of the note (glm; stabilized or not, joint
# or per-variable missingness models, trimming by the constant-cap approximation).

#' Stacked sandwich variance of weighted glm fits, estimated weights included
#'
#' Internal. With `psi_i = R_i w_i s_i(theta)` the casewise regression scores,
#' `w_i` the weight (`1 / p`, or `q / p` stabilized, each a product over the
#' per-variable models when there are several) and `S_b,i` the score of
#' missingness model `b`, `theta_hat - theta` is, to first order,
#' `H^{-1} sum_i (R_i psi_i + sum_b G_b H_b^{-1} S_b,i)` with `H = -sum d psi / d theta`,
#' `G_b = sum d psi / d gamma_b` and `H_b` the information of model `b`. Because
#' `psi_i` is linear in `w_i`, `G_b = sum_cc psi_i (d log w_i / d gamma_b)'` with
#' `d log w_i / d gamma_b = -(1 - p_b,i) z_b,i` for a denominator model and
#' `+(1 - q_b,i) t_b,i` for a stabilization numerator. The returned matrix is the
#' variance of that sum, for all regressions at once, so it carries the covariance
#' between the regressions that medfit stores as zero.
#'
#' Trimmed rows (weight capped at the `weight_trim` quantile) are treated as
#' constants: their `d w / d gamma` is zero and the estimation of the cap itself
#' is ignored (an approximation; the cap is a quantile of the weights).
#'
#' The dispersion of a Gaussian fit is treated as a constant, as `vcovHC` does;
#' it cancels from the result.
#' @param hc Small-sample correction (SPEC-ipw-stack-hc-gate-2026-10-09.md). The
#'   meat is `crossprod(U)`, so a row factor on the influence is squared in the
#'   variance. `"HC0"` (default): none. `"HC3"`: each complete case's regression
#'   score is divided by `1 - h_i` (`h_i = hatvalues(fit)`), as `sandwich`'s HC3.
#'   `"HC1"`: each regression's columns of the influence are scaled by
#'   `sqrt(n_cc / (n_cc - p))`, `p` that regression's coefficient count. The
#'   weight-model score term is not corrected. With the nuisance blocks removed,
#'   `"HC3"` and `"HC1"` equal `sandwich::vcovHC()` of each regression.
#' @param fits Named list of weighted `glm` fits on the complete cases, in the
#'   row order of the data. Their prior weights must be the weights in `info`.
#' @param info The `info` element of [.ipw_weights_info()].
#' @return A matrix over `c(coef(fits[[1]]), coef(fits[[2]]), ...)`, named
#'   `"<fit name>:<coefficient>"`.
#' @keywords internal
#' @noRd
.ipw_stacked_vcov <- function(fits, info, hc = c("HC0", "HC1", "HC3")) {
  hc <- match.arg(hc)
  if (!is.list(fits) || is.null(names(fits)) || !all(nzchar(names(fits)))) {
    stop("`fits` must be a named list of glm fits.", call. = FALSE)
  }
  cc <- info$cc
  N <- length(cc)
  n_cc <- sum(cc)
  trimmed <- info$trimmed
  w_cc <- ifelse(trimmed, info$cap, info$w_untrimmed)[cc]

  # Nuisance side, one entry per missingness model: score and information over
  # all rows (zero where the model dropped a row for a missing predictor).
  nuis <- lapply(info$blocks, function(b) {
    mod <- b$model
    # the rows the model was fitted on (a sequential factor uses a subset)
    used <- b$rows
    if (is.null(used)) {
      used <- seq_len(N)
      if (!is.null(mod$na.action)) used <- setdiff(used, as.integer(mod$na.action))
    }
    Z <- stats::model.matrix(mod)
    mu <- unname(stats::fitted(mod))
    Zf <- matrix(0, N, ncol(Z))
    Zf[used, ] <- Z
    pf <- rep(NA_real_, N)
    pf[used] <- mu
    if (anyNA(pf[cc])) {
      stop("A complete case has no fitted probability in a missingness model.",
        call. = FALSE)
    }
    Sg <- matrix(0, N, ncol(Z))
    Sg[used, ] <- Z * unname(stats::residuals(mod, type = "response"))
    list(
      sign = if (identical(b$kind, "num")) 1 else -1,
      Zf = Zf, pf = pf, Sg = Sg,
      Hg_inv = solve(crossprod(Z, Z * (mu * (1 - mu))))
    )
  })

  U <- lapply(names(fits), function(nm) {
    fit <- fits[[nm]]
    if (anyNA(stats::coef(fit))) {
      stop("`fits$", nm, "` has aliased coefficients.", call. = FALSE)
    }
    X <- stats::model.matrix(fit)
    if (nrow(X) != n_cc) {
      stop("`fits$", nm, "` was fitted on ", nrow(X), " rows; the complete-case ",
        "indicator has ", n_cc, ".", call. = FALSE)
    }
    if (!isTRUE(all.equal(unname(stats::weights(fit, "prior")), w_cc,
      tolerance = 1e-8))) {
      stop("`fits$", nm, "` was not fitted with the weights in `info` (the ",
        "capped, estimated IPW weights of the complete cases).", call. = FALSE)
    }
    ww <- unname(stats::weights(fit, "working"))
    psi <- X * (unname(stats::residuals(fit, "working")) * ww)
    H_inv <- solve(crossprod(X, X * ww))
    psi_hc <- psi
    if (hc == "HC3") {
      h <- unname(stats::hatvalues(fit))
      if (any(h >= 1 - 1e-8)) {
        stop("`fits$", nm, "` has ", sum(h >= 1 - 1e-8), " complete case(s) with ",
          "leverage 1, so the HC3 correction is undefined. Use hc = \"HC1\" or ",
          "\"HC0\".", call. = FALSE)
      }
      psi_hc <- psi / (1 - h)
    }
    # The leverage factor applies to the regression-score term only; the
    # derivative G of the score in the weights (below) uses the uncorrected score.
    Psi <- matrix(0, N, ncol(X))
    Psi[cc, ] <- psi_hc
    keep <- !trimmed[cc]
    for (b in nuis) {
      # psi_i is linear in w_i, so d psi_i / d gamma = psi_i (d log w_i / d gamma).
      G <- b$sign * crossprod(psi * ((1 - b$pf[cc]) * keep), b$Zf[cc, , drop = FALSE])
      Psi <- Psi + b$Sg %*% t(G %*% b$Hg_inv)
    }
    out <- Psi %*% H_inv
    if (hc == "HC1") out <- out * sqrt(n_cc / (n_cc - ncol(X)))
    colnames(out) <- paste0(nm, ":", names(stats::coef(fit)))
    out
  })
  U <- do.call(cbind, U)
  crossprod(U)
}
