# ML calibration gate for MBCO with engine = "lavaan"
# (SPEC-sem-mbco-2026-10-08.md, section 5, T8a). Not part of the package build.
#
#   Rscript dev/sim-sem-mbco-calibration.R REPS CORES [dgp] [n] [miss] > out.txt
#
# One cell = DGP x n x missingness x null. Size is the share of p < .05 over
# REPS replications (normal data, MAR, m = 20 mice imputations, ariv = "fixed").
suppressMessages(devtools::load_all(".", quiet = TRUE))
args <- commandArgs(TRUE)
reps <- as.integer(args[1]); cores <- as.integer(args[2])
dgps <- if (length(args) >= 3) args[3] else c("observed", "latent")
ns <- if (length(args) >= 4) as.integer(args[4]) else 200L
miss <- if (length(args) >= 5) as.numeric(args[5]) else 0.25
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
cells <- expand.grid(dgp = dgps, n = ns, miss = miss, null = seq_along(nulls), stringsAsFactors = FALSE)
for (i in seq_len(nrow(cells))) {
  cl <- cells[i, ]; ab <- nulls[[cl$null]]
  t0 <- Sys.time()
  p <- unlist(parallel::mclapply(seq_len(reps), function(s) one(cl$dgp, cl$n, ab[1], ab[2], cl$miss, 5000 + s), mc.cores = cores))
  ok <- !is.na(p)
  cat(sprintf("%-8s n=%d miss=%.2f (a,b)=(%.1f,%.1f) reps=%d failed=%d size@5%%=%.3f  [%.0fs]\n",
    cl$dgp, cl$n, cl$miss, ab[1], ab[2], sum(ok), sum(!ok), mean(p[ok] < .05), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
