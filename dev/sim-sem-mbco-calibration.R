# ML calibration gate for MBCO with engine = "lavaan"
# (SPEC-sem-mbco-2026-10-08.md, section 5, T8a). Not part of the package build.
#
#   Rscript dev/sim-sem-mbco-calibration.R REPS CORES [dgp] [n] [miss] > out.txt
#
# One cell = DGP x n x missingness x null. Size is the share of p < .05 over
# REPS replications (normal data, MAR, m = 20 mice imputations, ariv = "fixed").
source("dev/sim-sem-mbco-lib.R")
args <- commandArgs(TRUE)
reps <- as.integer(args[1]); cores <- as.integer(args[2])
dgps <- if (length(args) >= 3) args[3] else c("observed", "latent")
ns <- if (length(args) >= 4) as.integer(args[4]) else 200L
miss <- if (length(args) >= 5) as.numeric(args[5]) else 0.25
cells <- expand.grid(dgp = dgps, n = ns, miss = miss, null = seq_along(nulls), stringsAsFactors = FALSE)
for (i in seq_len(nrow(cells))) {
  cl <- cells[i, ]; ab <- nulls[[cl$null]]
  t0 <- Sys.time()
  p <- unlist(parallel::mclapply(seq_len(reps), function(s) one(cl$dgp, cl$n, ab[1], ab[2], cl$miss, 5000 + s), mc.cores = cores))
  ok <- !is.na(p)
  cat(sprintf("%-8s n=%d miss=%.2f (a,b)=(%.1f,%.1f) reps=%d failed=%d size@5%%=%.3f  [%.0fs]\n",
    cl$dgp, cl$n, cl$miss, ab[1], ab[2], sum(ok), sum(!ok), mean(p[ok] < .05), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
