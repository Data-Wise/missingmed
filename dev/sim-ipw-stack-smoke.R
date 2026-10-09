# Laptop checks for the IPW coverage gate (SPEC-ipw-stack-coverage-2026-10-09.md).
#   Rscript dev/sim-ipw-stack-smoke.R --defs        T1: cells, truth, rates, stored definitions
#   Rscript dev/sim-ipw-stack-smoke.R --write-defs  rewrite dev/sim-ipw-stack-cells.rds (T1 only)
source("dev/sim-ipw-stack-lib.R")
args <- commandArgs(TRUE)
defs_file <- "dev/sim-ipw-stack-cells.rds"

check_defs <- function() {
  cells <- ipw_cells()
  stopifnot(nrow(cells) == 48)
  # truth: complete-data population (a, b) equal the nominal values
  # One truth per (dgm, n-independent) setting is enough: truth does not depend on
  # n, miss or alpha, so check every distinct (dgm, point).
  u <- cells[!duplicated(paste(cells$dgm, cells$point)), ]
  tr <- t(vapply(seq_len(nrow(u)), function(i) ipw_truth(u[i, ]), c(a = 0, b = 0)))
  dev_ab <- pmax(abs(tr[, "a"] - u$a), abs(tr[, "b"] - u$b))
  cat(sprintf("truth: max |population - nominal| over %d (dgm, point) = %.4f (bar 0.005)\n",
    nrow(u), max(dev_ab)))
  ok_truth <- max(dev_ab) < .005
  # missing rates: each of M and Y within 0.02 of nominal on a 2e5-row draw
  rate_dev <- vapply(seq_len(nrow(cells)), function(i) {
    cl <- cells[i, ]
    d <- gen_ipw(cl$dgm, 2e5, cl$a, cl$b, cl$miss, cl$alpha, seed = 11)
    max(abs(mean(is.na(d$M)) - cl$miss), abs(mean(is.na(d$Y)) - cl$miss))
  }, 0)
  cat(sprintf("rates: max |missing share - nominal| over 48 cells = %.4f (bar 0.02)\n", max(rate_dev)))
  ok_rates <- max(rate_dev) < .02
  # stored definitions
  ok_defs <- if (file.exists(defs_file)) {
    isTRUE(all.equal(cells, readRDS(defs_file), tolerance = 1e-8))
  } else FALSE
  cat(sprintf("stored definitions (%s): %s\n", defs_file, if (ok_defs) "identical" else "MISSING OR DIFFERENT"))
  if (!(ok_truth && ok_rates && ok_defs)) stop("T1 checks FAILED", call. = FALSE)
  cat("48 cells, truth within 0.005, rates within 0.02, definitions identical: OK\n")
}

# Planted defect: without the auxiliary-variable correction of the structural b the
# truth check must fail for auxm (marginal b = b_s + 0.49 / 1.49 = b_s + 0.329).
check_planted <- function() {
  cl <- ipw_cells(); cl <- cl[cl$dgm == "auxm" & cl$point == "P3", ][1, ]
  dev_b <- abs(ipw_truth(cl, b_correct = FALSE)["b"] - cl$b)
  cat(sprintf("planted defect (auxm, b uncorrected): |b - nominal| = %.3f; caught = %s\n",
    dev_b, dev_b >= .005))
  if (dev_b < .005) stop("planted defect NOT caught", call. = FALSE)
}

if ("--write-defs" %in% args) {
  saveRDS(ipw_cells(), defs_file); cat("wrote", defs_file, "\n")
}
if ("--defs" %in% args) { check_defs(); check_planted() }
