# Laptop checks for the second IPW coverage gate (SPEC-ipw-stack-hc-gate-2026-10-09.md).
#   Rscript dev/sim-ipw-stack-smoke.R --write-defs   write the stored cells and population truth (T3 only)
#   Rscript dev/sim-ipw-stack-smoke.R --defs         cells, truth, missing shares, mechanisms, stored definitions
#   Rscript dev/sim-ipw-stack-smoke.R --controls     controls 1, 3 and 5, timing
source("dev/sim-ipw-stack-lib.R")
args <- commandArgs(TRUE)
defs_file <- "dev/sim-ipw-stack-cells.rds"

write_defs <- function() {
  cells <- ipw_cells()
  saveRDS(cells, defs_file)
  u <- cells[!duplicated(paste(cells$dgm, cells$point)), ]
  tr <- t(vapply(seq_len(nrow(u)), function(i) ipw_truth(u[i, ]), c(a = 0, b = 0)))
  tt <- data.frame(dgm = u$dgm, point = u$point, nominal_a = u$a, nominal_b = u$b,
    a = unname(tr[, "a"]), b = unname(tr[, "b"]))
  tt$ab <- tt$a * tt$b
  saveRDS(tt, ipw_truth_file)
  cat("wrote", defs_file, "(", nrow(cells), "cells ) and", ipw_truth_file, "(", nrow(tt), "rows )\n")
}

check_defs <- function() {
  cells <- ipw_cells()
  stopifnot(nrow(cells) == 96, length(unique(cells$dgm)) == 6)
  tt <- ipw_truth_table()
  dev_ab <- max(abs(tt$a - tt$nominal_a), abs(tt$b - tt$nominal_b))
  cat(sprintf("truth: max |population - nominal| over %d (dgm, point) = %.4f (bar 0.005)\n", nrow(tt), dev_ab))
  ok_truth <- nrow(tt) == 24 && dev_ab < .005
  rate_dev <- vapply(seq_len(nrow(cells)), function(i) {
    cl <- cells[i, ]
    d <- gen_ipw(cl$dgm, 2e5, cl$a, cl$b, cl$miss, cl$alpha, seed = 11)
    max(abs(mean(is.na(d$M)) - cl$miss), abs(mean(is.na(d$Y)) - cl$miss))
  }, 0)
  cat(sprintf("rates: max |missing share - nominal| over 96 cells = %.4f (bar 0.02)\n", max(rate_dev)))
  ok_rates <- max(rate_dev) < .02
  # mechanism: joint DGMs miss M and Y together, independent DGMs do not
  mech <- vapply(names(ipw_dgms), function(dg) {
    cl <- cells[cells$dgm == dg & cells$n == 500 & cells$miss == .40 & cells$point == "P4", ][1, ]
    d <- gen_ipw(dg, 2e5, cl$a, cl$b, cl$miss, cl$alpha, seed = 12)
    mean(is.na(d$M) == is.na(d$Y))
  }, 0)
  cat("mechanism: share of rows where M and Y are both or neither missing:",
    paste(sprintf("%s %.2f", names(mech), mech), collapse = ", "), "\n")
  ok_mech <- all(mech[c("stdj", "auxj", "auxmj")] == 1) && all(mech[c("std", "aux", "auxm")] < .999)
  ok_defs <- file.exists(defs_file) && isTRUE(all.equal(cells, readRDS(defs_file), tolerance = 1e-8))
  cat(sprintf("stored definitions (%s): %s\n", defs_file, if (ok_defs) "identical" else "MISSING OR DIFFERENT"))
  if (!(ok_truth && ok_rates && ok_mech && ok_defs)) stop("definition checks FAILED", call. = FALSE)
  cat("96 cells, truth within 0.005, rates within 0.02, mechanisms as specified, definitions identical: OK\n")
  # planted defect: without the correction of the structural b the truth check must fail for auxm
  cl <- cells[cells$dgm == "auxm" & cells$point == "P3", ][1, ]
  dev_b <- abs(ipw_truth(cl, b_correct = FALSE)["b"] - cl$b)
  cat(sprintf("planted defect (auxm, b uncorrected): |b - nominal| = %.3f; caught = %s\n", dev_b, dev_b >= .005))
  if (dev_b < .005) stop("planted defect NOT caught", call. = FALSE)
}

check_controls <- function() {
  cells <- ipw_cells()
  # Timing: 20 replications of one cell, all arms.
  cl <- cells[cells$dgm == "auxmj" & cells$n == 500 & cells$miss == .40 & cells$point == "P4", ][1, ]
  t0 <- Sys.time(); r <- do.call(rbind, lapply(1:20, function(s) one_ipw(cl, 5000 + s)))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("timing: 20 replications of one cell = %.1fs (bar 15s); rows %d; error rows: %d; non-PD stacked: %d\n",
    secs, nrow(r), sum(!is.na(r$error)), sum(grepl("^stacked", r$arm) & r$pd == 0, na.rm = TRUE)))
  ok <- secs < 15 && all(c("stacked_hc0", "stacked_hc1", "stacked_hc3", "ess", "max_w_share") %in% c(r$arm, names(r)))
  # Control 1: known_hc3 is what infer(type = "mc") returns on the real run() -> pool() result
  # (bar 0.01 + 0.02 x width per endpoint); positive control: known_hc0 must exceed it somewhere.
  excess <- c(known_hc3 = -Inf, known_hc0 = -Inf)
  for (dg in c("std", "auxm", "auxmj")) for (nm_cell in list(c(500, .25), c(200, .40))) {
    cl <- cells[cells$dgm == dg & cells$n == nm_cell[1] & cells$miss == nm_cell[2] & cells$point == "P4", ][1, ]
    for (s in 1:30) {
      d <- gen_ipw(cl$dgm, cl$n, cl$a, cl$b, cl$miss, cl$alpha, 9000 + s)
      for (nm in c("uj", "sj")) {
        md <- suppressWarnings(do.call(set_md_mediation, c(
          list(d, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M", method = "ipw"), ipw_forms[[nm]])))
        set.seed(1)
        shipped <- suppressWarnings(infer(pool(run(md)), type = "mc", n.mc = 1e5))$CI
        bar <- .01 + .02 * (shipped[2] - shipped[1])
        rr <- one_ipw(cl, 9000 + s, forms = ipw_forms[nm])
        for (arm in names(excess)) {
          x <- rr[rr$arm == arm, ]
          excess[arm] <- max(excess[arm], abs(shipped[1] - x$lo) - bar, abs(shipped[2] - x$hi) - bar)
        }
      }
    }
  }
  cat(sprintf("control 1: max (|endpoint - shipped infer(mc)| - bar) over 360 intervals: known_hc3 %.4f (must be <= 0), known_hc0 %.4f (must be > 0)\n",
    excess["known_hc3"], excess["known_hc0"]))
  ok1 <- excess["known_hc3"] <= 0 && excess["known_hc0"] > 0
  # Control 3: stacked_hc0 SE vs bootstrap of the whole pipeline (3 draws per DGM, the DGM's first
  # decisive form); ratio in [0.90, 1.10]. The HC3 ratio is reported (expected larger).
  worst3 <- 0; r3 <- numeric(); lr <- numeric()
  for (dg in names(ipw_dgms)) {
    cl <- cells[cells$dgm == dg & cells$n == 500 & cells$miss == .25 & cells$point == "P4", ][1, ]
    fm <- ipw_decisive[[dg]][1]
    for (s in 1:3) {
      d <- gen_ipw(cl$dgm, cl$n, cl$a, cl$b, cl$miss, cl$alpha, 9100 + s)
      f <- ipw_fit(d, ipw_forms[[fm]])
      se <- function(hc) { V <- missingmed:::.ipw_stacked_vcov(f$fits, f$info, hc = hc); sqrt(c(V["m:X", "m:X"], V["y:M", "y:M"])) }
      set.seed(40 + s)
      bt <- t(vapply(1:500, function(r) {
        g <- ipw_fit(d[sample(nrow(d), replace = TRUE), ], ipw_forms[[fm]])
        if (!is.null(g$error)) return(c(NA_real_, NA_real_))
        c(unname(stats::coef(g$fits$m)["X"]), unname(stats::coef(g$fits$y)["M"]))
      }, c(0, 0)))
      bse <- apply(bt, 2, stats::sd, na.rm = TRUE)
      worst3 <- max(worst3, abs(log(se("HC0") / bse))); lr <- c(lr, log(se("HC0") / bse))
      r3 <- c(r3, se("HC3") / se("HC0"))
    }
  }
  cat(sprintf("control 3 (B = 500): worst |log(stacked_hc0 SE / bootstrap SE)| over 18 draws x 2 coefficients = %.3f (bar log 1.10 = %.3f); mean log ratio %.3f; HC3/HC0 SE ratio range %.3f to %.3f\n",
    worst3, log(1.10), mean(lr), min(r3), max(r3)))
  ok3 <- worst3 < log(1.10)
  # Control 5: the specification split is real. At n = 1e5 the correct form recovers b (within 0.01 of
  # the stored truth); on auxm the misspecified joint forms do not (so the control can fail).
  tt <- ipw_truth_table(); bres <- list()
  for (dg in names(ipw_dgms)) {
    cl <- cells[cells$dgm == dg & cells$n == 500 & cells$miss == .40 & cells$point == "P4", ][1, ]
    tb <- tt$b[tt$dgm == dg & tt$point == "P4"]
    bb <- rowMeans(vapply(1:4, function(s) {
      d <- gen_ipw(dg, 1e5, cl$a, cl$b, cl$miss, cl$alpha, 50000 + s)
      c(uj = unname(coef(ipw_fit(d, ipw_forms$uj)$fits$y)["M"]), spv = unname(coef(ipw_fit(d, ipw_forms$spv)$fits$y)["M"]))
    }, c(uj = 0, spv = 0)))
    bres[[dg]] <- c(truth = tb, bb)
  }
  b5 <- do.call(rbind, bres)
  cat("control 5: mean b at n = 1e5, 4 reps (truth / uj / spv):\n"); print(round(b5, 3))
  dec <- vapply(names(ipw_dgms), function(dg) {
    f <- if (dg %in% c("std", "aux", "auxm")) "spv" else "uj"; abs(b5[dg, f] - b5[dg, "truth"]) < .01 }, NA)
  ok5 <- all(dec) && abs(b5["auxm", "uj"] - b5["auxm", "truth"]) >= .01
  cat(sprintf("control 5: correct form within 0.01 of truth in all 6 DGMs: %s; joint form on auxm off by >= 0.01 (can fail): %s\n",
    all(dec), abs(b5["auxm", "uj"] - b5["auxm", "truth"]) >= .01))
  if (!(ok && ok1 && ok3 && ok5)) stop("controls FAILED", call. = FALSE)
  cat("controls 1, 3, 5 and timing: OK\n")
}

if ("--write-defs" %in% args) write_defs()
if ("--defs" %in% args) check_defs()
if ("--controls" %in% args) check_controls()
