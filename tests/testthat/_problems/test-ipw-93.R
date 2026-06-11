# Extracted from test-ipw.R:93

# prequel ----------------------------------------------------------------------
skip_if_not_installed("medfit")
skip_if_not_installed("RMediation")
make_ipw_data <- function(seed = 2026, n = 600) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, plogis(0.3 * C))
  M <- 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.4 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[plogis(-1.2 + 0.4 * d$X + 0.4 * d$C) > runif(n)] <- NA
  d$Y[plogis(-1.2 + 0.4 * d$X + 0.4 * d$C) > runif(n)] <- NA
  d
}

# test -------------------------------------------------------------------------
d <- make_ipw_data()
md_trim <- set_md_mediation(d, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", method = "ipw", weight_trim = 0.90)
w <- missingmed:::.ipw_weights(md_trim)
cc <- !is.na(w)
expect_lte(max(w[cc]), stats::quantile(w[cc], 0.90, names = FALSE) + 1e-8)
