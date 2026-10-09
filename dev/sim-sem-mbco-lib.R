# Shared pieces of the ML calibration gate for MBCO with engine = "lavaan"
# (SPEC-sem-mbco-2026-10-08.md, section 5, T8a). Sourced by
# sim-sem-mbco-calibration.R (local pilot) and
# sim-sem-mbco-calibration-hopper.R (SLURM array). Not part of the package build.
if (nzchar(Sys.getenv("SIM_INSTALLED"))) {
  suppressMessages(library(missingmed))
} else {
  suppressMessages(devtools::load_all(".", quiet = TRUE))
}
nulls <- list(c(0, .3), c(.3, 0), c(0, 0), c(0, .1), c(.1, 0))

gen <- function(dgp, n, a, b, miss, seed) {
  set.seed(seed)
  X <- rnorm(n)
  if (dgp == "observed") {
    C <- rnorm(n); M <- a * X + .3 * C + rnorm(n); Y <- b * M + .2 * X + .3 * C + rnorm(n)
    d <- data.frame(X, M, Y, C)
    d$M[runif(n) < plogis(qlogis(miss) + .6 * d$C + .5 * d$Y)] <- NA
  } else {
    L <- a * X + rnorm(n)
    d <- data.frame(X, m1 = L + rnorm(n, 0, .6), m2 = .8 * L + rnorm(n, 0, .6), m3 = .7 * L + rnorm(n, 0, .6))
    d$Y <- b * L + .2 * X + rnorm(n)
    for (v in c("m1", "m2", "m3")) d[[v]][runif(n) < plogis(qlogis(miss) + .5 * d$Y + .3 * d$X)] <- NA
  }
  d
}
one <- function(dgp, n, a, b, miss, seed) {
  d <- gen(dgp, n, a, b, miss, seed)
  imp <- suppressWarnings(mice::mice(d, m = 20, maxit = 5, method = "norm", printFlag = FALSE, seed = seed))
  il <- mice::complete(imp, "all")
  model <- if (dgp == "observed") "M ~ X + C\nY ~ M + X + C" else "Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ Ml + X"
  med <- if (dgp == "observed") "M" else "Ml"
  r <- tryCatch(suppressWarnings(mbco_d4(il, model = model, treatment = "X", mediator = med, outcome = "Y")),
    error = function(e) NULL)
  if (is.null(r)) NA_real_ else unname(r["p"])
}
