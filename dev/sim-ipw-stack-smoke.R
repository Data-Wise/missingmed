# Laptop checks for the IPW coverage gate (SPEC-ipw-stack-coverage-2026-10-09.md).
#   Rscript dev/sim-ipw-stack-smoke.R --defs        T1: cells, truth, rates, stored definitions
#   Rscript dev/sim-ipw-stack-smoke.R --write-defs  rewrite dev/sim-ipw-stack-cells.rds (T1 only)
#   Rscript dev/sim-ipw-stack-smoke.R --controls    T2: controls 1 and 3, timing
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

# T2: controls 1 and 3 and timing.
check_controls <- function() {
  cells <- ipw_cells()
  # Timing: 20 replications of one cell.
  cl <- cells[cells$dgm == "auxm" & cells$n == 500 & cells$miss == .40 & cells$point == "P4", ][1, ]
  t0 <- Sys.time(); r <- do.call(rbind, lapply(1:20, function(s) one_ipw(cl, 5000 + s)))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("timing: 20 replications of one cell = %.1fs (bar 10s); error rows: %d; non-PD stacked: %d\n",
    secs, sum(!is.na(r$error)), sum(r$arm == "stacked" & r$pd == 0, na.rm = TRUE)))
  ok <- secs < 10
  # Control 1: the known_hc3 interval is what infer(type = "mc") returns on the real
  # run() -> pool() result. The shipped interval has Monte-Carlo noise that grows with
  # its width, so the bar is 0.01 + 0.02 * width per endpoint (50 replications in each
  # of two cells per DGM; unstabilized and stabilized joint). Positive control: the
  # known_hc0 arm (the HC0/HC3 difference is large in small samples) must exceed the
  # same bar somewhere, otherwise the control cannot tell a wrong covariance from the shipped one.
  excess <- c(known_hc3 = -Inf, known_hc0 = -Inf); worst1 <- 0
  for (dg in names(ipw_dgms)) for (nm_cell in list(c(500, .25), c(200, .40))) {
    cl <- cells[cells$dgm == dg & cells$n == nm_cell[1] & cells$miss == nm_cell[2] & cells$point == "P4", ][1, ]
    for (s in 1:50) {
      d <- gen_ipw(cl$dgm, cl$n, cl$a, cl$b, cl$miss, cl$alpha, 9000 + s)
      for (nm in c("uj", "sj")) {
        md <- suppressWarnings(do.call(set_md_mediation, c(
          list(d, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M", method = "ipw"), ipw_forms[[nm]])))
        set.seed(1)
        shipped <- suppressWarnings(infer(pool(run(md)), type = "mc", n.mc = 1e5))$CI
        bar <- .01 + .02 * (shipped[2] - shipped[1])
        r <- one_ipw(cl, 9000 + s, forms = ipw_forms[nm])
        for (arm in names(excess)) {
          x <- r[r$arm == arm, ]
          excess[arm] <- max(excess[arm], abs(shipped[1] - x$lo) - bar, abs(shipped[2] - x$hi) - bar)
        }
      }
    }
  }
  cat(sprintf("control 1: max (|endpoint - shipped infer(mc)| - bar) over 600 intervals: known_hc3 %.4f (must be <= 0), known_hc0 %.4f (must be > 0)\n",
    excess["known_hc3"], excess["known_hc0"]))
  ok1 <- excess["known_hc3"] <= 0 && excess["known_hc0"] > 0
  # Control 3: stacked SE vs bootstrap of the whole pipeline on 3 draws (ratio in [0.90, 1.10]).
  worst3 <- c(0, 0)
  cl <- cells[cells$dgm == "auxm" & cells$n == 500 & cells$miss == .25 & cells$point == "P4", ][1, ]
  for (s in 1:3) {
    d <- gen_ipw(cl$dgm, cl$n, cl$a, cl$b, cl$miss, cl$alpha, 9100 + s)
    for (nm in c("uj", "sj")) {
      f <- ipw_fit(d, ipw_forms[[nm]])
      V <- missingmed:::.ipw_stacked_vcov(f$fits, f$info)
      se <- sqrt(c(V["m:X", "m:X"], V["y:M", "y:M"]))
      set.seed(40 + s)
      bt <- t(vapply(1:400, function(r) {
        g <- ipw_fit(d[sample(nrow(d), replace = TRUE), ], ipw_forms[[nm]])
        if (!is.null(g$error)) return(c(NA_real_, NA_real_))
        c(unname(stats::coef(g$fits$m)["X"]), unname(stats::coef(g$fits$y)["M"]))
      }, c(0, 0)))
      bse <- apply(bt, 2, stats::sd, na.rm = TRUE)
      worst3 <- pmax(worst3, abs(log(se / bse)))
    }
  }
  cat(sprintf("control 3: worst |log(stacked SE / bootstrap SE)| over 3 draws x 2 forms: a %.3f, b %.3f (bar log 1.10 = %.3f)\n",
    worst3[1], worst3[2], log(1.10)))
  ok3 <- all(worst3 < log(1.10))
  if (!(ok && ok1 && ok3)) stop("T2 controls FAILED", call. = FALSE)
  cat("T2 controls: OK\n")
}
if ("--controls" %in% args) check_controls()
