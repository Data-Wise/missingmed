# Checks for the missingness-model gate (SPEC-ipw-missingness-default-2026-10-09.md).
#   Rscript dev/sim-ipw-mech-smoke.R --write-defs   write the stored cells (T1 only)
#   Rscript dev/sim-ipw-mech-smoke.R --defs         cells, shares, mechanism structure, true P(complete), stored cells
#   Rscript dev/sim-ipw-mech-smoke.R --units        degenerate and error handling of the weight factors
#   Rscript dev/sim-ipw-mech-smoke.R --controls [REPS]   planted-defect and known-weights controls at the gate's own cells
#   Rscript dev/sim-ipw-mech-smoke.R --package      joint and marginal weights equal the package's (needs missingmed)
source("dev/sim-ipw-mech-lib.R")
args <- commandArgs(TRUE)
defs_file <- "dev/sim-ipw-mech-cells.rds"
ok_all <- TRUE
report <- function(label, ok) { cat(sprintf("%-4s %s\n", if (ok) "PASS" else "FAIL", label)); ok_all <<- ok_all && ok }

if ("--write-defs" %in% args) {
  cells <- mech_cells(); saveRDS(cells, defs_file)
  cat("wrote", defs_file, "(", nrow(cells), "cells )\n")
}

if ("--defs" %in% args) {
  cells <- mech_cells()
  report("162 cells, 3 mechanisms x 3 DGMs x 3 n x 2 miss x 3 points", nrow(cells) == 162 && all(table(cells$mech) == 54))
  # shares and structure, large n at one cell per mechanism and DGM
  for (m in MECHS) for (dg in MECH_DGMS) {
    cl <- cells[cells$mech == m & cells$dgm == dg & cells$n == 500 & cells$miss == .40 & cells$point == "P4", ][1, ]
    cl$n <- 2e5; d <- gen_mech(cl, 12)
    exp_m <- if (m == "mono") .20 else .40
    report(sprintf("%s/%s: M share %.3f (nominal %.2f), Y share %.3f (nominal 0.40)", m, dg,
      mean(is.na(d$M)), exp_m, mean(is.na(d$Y))), abs(mean(is.na(d$M)) - exp_m) < .01 && abs(mean(is.na(d$Y)) - .40) < .01)
    cc <- complete.cases(d[, c("M", "Y")])
    report(sprintf("%s/%s: mean true P(complete) %.3f = observed complete share %.3f", m, dg, mean(attr(d, "p_cc")), mean(cc)),
      abs(mean(attr(d, "p_cc")) - mean(cc)) < .005)
    struct <- switch(m,
      sim = all(is.na(d$M) == is.na(d$Y)),
      mono = all((!is.na(d$Y)) <= (!is.na(d$M))) && any(is.na(d$Y) & !is.na(d$M)),   # Y observed implies M observed
      ind = any(is.na(d$M) & !is.na(d$Y)) && any(!is.na(d$M) & is.na(d$Y)))
    report(sprintf("%s/%s: mechanism structure", m, dg), struct)
  }
  if (file.exists(defs_file)) {
    report("stored cells equal the regenerated cells", isTRUE(all.equal(readRDS(defs_file), cells)))
  } else cat("NOTE no stored cells yet (run --write-defs)\n")
}

if ("--units" %in% args) {
  d <- data.frame(X = rbinom(400, 1, .5), C = rnorm(400), Z = rnorm(400))
  R <- rep(TRUE, 400)
  f <- .fit_factor(R, RHS, d, rep(TRUE, 400))
  report("a factor observed on every fitted row is probability 1 and flagged degenerate", all(f$p == 1) && f$degenerate == 1L)
  R2 <- rbinom(400, 1, plogis(d$Z)) == 1
  f2 <- .fit_factor(R2, RHS, d, rep(TRUE, 400))
  report("an ordinary factor is fitted, not flagged", f2$degenerate == 0L && all(f2$p > 0 & f2$p < 1))
  report("an all-zero response is an error", inherits(try(.fit_factor(!R, RHS, d, rep(TRUE, 400)), silent = TRUE), "try-error"))
  # sequential = marginal when missingness is independent in expectation? No: check the identity on a toy
  # where the answer is known: M and Y missing together, so P(M obs) x P(Y obs | M obs) = P(M obs) exactly.
  cl <- mech_cells(); cl <- cl[cl$mech == "sim" & cl$dgm == "aux" & cl$n == 500 & cl$miss == .40 & cl$point == "P4", ][1, ]
  dd <- gen_mech(cl, 3)
  wj <- mech_weights(dd, "joint")$w; ws <- mech_weights(dd, "seq")$w
  report("under simultaneous missingness the sequential weights equal the joint weights", isTRUE(all.equal(wj, ws, tolerance = 1e-10)))
  report("... and the second factor is flagged degenerate", mech_weights(dd, "seq")$degenerate == 1L)
  wm <- mech_weights(dd, "marginal")$w
  report("... while the marginal product differs (the planted defect)", max(abs(wm - wj), na.rm = TRUE) > .05)
}

if ("--controls" %in% args) {
  reps <- suppressWarnings(as.integer(args[which(args == "--controls") + 1L])); if (is.na(reps)) reps <- 40L
  cells <- mech_cells()
  cat(sprintf("\nControls at n = 5000, miss 0.40, P4; %d replications each; mean bias in b against the stored population b\n", reps))
  t0 <- Sys.time()
  for (m in MECHS) for (dg in MECH_DGMS) {
    cl <- cells[cells$mech == m & cells$dgm == dg & cells$n == 5000 & cells$miss == .40 & cells$point == "P4", ][1, ]
    ci <- as.integer(rownames(cl))
    r <- do.call(rbind, lapply(seq_len(reps), function(s) one_mech(cl, 5000 + 100000 * ci + s)))
    b <- tapply(r$b - r$truth_b, r$form, mean, na.rm = TRUE)
    cat(sprintf("%-4s %-4s %s\n", m, dg, paste(sprintf("%s %+.3f", names(b), b), collapse = "  ")))
  }
  cat(sprintf("[%.0fs]\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

if ("--package" %in% args) {
  if (nzchar(Sys.getenv("SIM_INSTALLED"))) suppressMessages(library(missingmed)) else suppressMessages(devtools::load_all(".", quiet = TRUE))
  cells <- mech_cells()
  cl <- cells[cells$mech == "ind" & cells$dgm == "aux" & cells$n == 500 & cells$miss == .40 & cells$point == "P4", ][1, ]
  d <- gen_mech(cl, 9)
  pkg_w <- function(wf) {
    md <- suppressWarnings(set_md_mediation(d, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M",
      method = "ipw", weight_formula = wf, weight_stabilize = TRUE))
    missingmed:::.ipw_weights_info(md)$w
  }
  report("joint weights equal the package's weight_formula = ~ X + C + Z", isTRUE(all.equal(mech_weights(d, "joint")$w, pkg_w(~ X + C + Z), tolerance = 1e-8)))
  report("marginal weights equal the package's per-variable list", isTRUE(all.equal(mech_weights(d, "marginal")$w,
    pkg_w(list(M = ~ X + C + Z, Y = ~ X + C + Z)), tolerance = 1e-8)))
}

cat(if (ok_all) "\nALL CHECKS PASSED\n" else "\nSOME CHECKS FAILED\n")
quit(status = if (ok_all) 0L else 1L)
