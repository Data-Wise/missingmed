# Variance of the IPW regression coefficients that accounts for estimating the
# weights. Design: docs/specs/NOTE-ipw-weight-score-stacking-2026-10-09.md.
# Not yet wired into run(); step 2 of the note (glm, unstabilized, no trimming,
# one joint missingness model).

#' Stacked sandwich variance of weighted glm fits, estimated weights included
#'
#' Internal. With `psi_i = R_i w_i s_i(theta)` the casewise regression scores,
#' `w_i = 1 / p_i(gamma)` and `S_i` the score of the missingness model,
#' `theta_hat - theta` is, to first order, `H^{-1} sum_i (R_i psi_i + G H_gamma^{-1} S_i)`
#' with `H = -sum d psi / d theta`, `G = sum d psi / d gamma` and `H_gamma` the
#' information of the missingness model. The returned matrix is the variance of
#' that sum, for all regressions at once, so it carries the covariance between
#' the regressions that medfit stores as zero.
#'
#' The dispersion of a Gaussian fit is treated as a constant, as `vcovHC` does;
#' it cancels from the result.
#' @param fits Named list of weighted `glm` fits on the complete cases, in the
#'   row order of the data. Their prior weights must be `1 / p` of the
#'   missingness model in `info`.
#' @param info The `info` element of [.ipw_weights_info()].
#' @return A matrix over `c(coef(fits[[1]]), coef(fits[[2]]), ...)`, named
#'   `"<fit name>:<coefficient>"`.
#' @keywords internal
#' @noRd
.ipw_stacked_vcov <- function(fits, info) {
  if (isTRUE(info$stabilize) || isTRUE(info$per_var) || any(info$trimmed)) {
    stop("The stacked IPW variance is implemented for unstabilized weights from ",
      "a joint missingness model without trimming only.", call. = FALSE)
  }
  if (!is.list(fits) || is.null(names(fits)) || !all(nzchar(names(fits)))) {
    stop("`fits` must be a named list of glm fits.", call. = FALSE)
  }
  cc <- info$cc
  N <- length(cc)
  n_cc <- sum(cc)
  blk <- info$blocks

  # Gamma side: score and information of the missingness model over all rows
  # (zero where the model dropped a row for a missing predictor).
  have_gamma <- length(blk) > 0L
  if (have_gamma) {
    mod <- blk[[1L]]$model
    used <- seq_len(N)
    if (!is.null(mod$na.action)) used <- setdiff(used, as.integer(mod$na.action))
    Z <- stats::model.matrix(mod)
    mu <- unname(stats::fitted(mod))
    Zf <- matrix(0, N, ncol(Z))
    Zf[used, ] <- Z
    pf <- rep(NA_real_, N)
    pf[used] <- mu
    Sg <- matrix(0, N, ncol(Z))
    Sg[used, ] <- Z * unname(stats::residuals(mod, type = "response"))
    Hg_inv <- solve(crossprod(Z, Z * (mu * (1 - mu))))
    if (anyNA(pf[cc])) {
      stop("A complete case has no fitted missingness probability.", call. = FALSE)
    }
  }

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
    if (have_gamma && !isTRUE(all.equal(unname(stats::weights(fit, "prior")),
      1 / pf[cc], tolerance = 1e-8))) {
      stop("`fits$", nm, "` was not fitted with weights 1 / p from the ",
        "missingness model.", call. = FALSE)
    }
    ww <- unname(stats::weights(fit, "working"))
    psi <- X * (unname(stats::residuals(fit, "working")) * ww)
    H_inv <- solve(crossprod(X, X * ww))
    Psi <- matrix(0, N, ncol(X))
    Psi[cc, ] <- psi
    if (have_gamma) {
      # psi_i is linear in w_i = 1 / p_i, and d w_i / d gamma = -w_i (1 - p_i) z_i.
      G <- -crossprod(psi * (1 - pf[cc]), Zf[cc, , drop = FALSE])
      Psi <- Psi + Sg %*% t(G %*% Hg_inv)
    }
    out <- Psi %*% H_inv
    colnames(out) <- paste0(nm, ":", names(stats::coef(fit)))
    out
  })
  U <- do.call(cbind, U)
  crossprod(U)
}
