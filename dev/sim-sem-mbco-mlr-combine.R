# Combine the MLR gate's array outputs and apply the section 5 criterion:
#   Rscript dev/sim-sem-mbco-mlr-combine.R SIM_OUT [REPS=1000] [MAX_REFUSED_PCT=5]
# Exit status 0 only when the run is COMPLETE (every expected cell, each with
# exactly REPS unique replication ids), VALID (no cell above MAX_REFUSED_PCT
# refused or failed replications: its size would be conditional on success), and
# every cell's size of the scaled D4 is at most 0.065. Anything else exits 1 and
# prints why, so a pilot or a partial run can never print PASS.
# Reported per cell: the scaled D4 (the statistic under test), the naive D4 and
# D2 (comparators), failed replications and the NA share of every p-value column.
args <- commandArgs(TRUE)
d <- args[1]
reps_expected <- if (length(args) >= 2) as.integer(args[2]) else 1000L
max_refused <- if (length(args) >= 3) as.numeric(args[3]) else 5
bar <- 0.065

# The expected grid, as in mlr_cells() and `nulls` of the lib (kept inline so
# this script runs without loading the package).
nulls <- list(c(0, .3), c(.3, 0), c(0, 0), c(0, .1), c(.1, 0))
grid <- expand.grid(dist = c("skewed", "heavy"), dgp = c("observed", "latent"), n = c(200L, 500L),
  miss = c(0.25, 0.40), null = seq_along(nulls), stringsAsFactors = FALSE)
fmt <- function(dist, dgp, n, miss, a, b) sprintf("%-6s %-8s n=%d miss=%.2f (%.1f,%.1f)", dist, dgp, n, miss, a, b)
expected <- fmt(grid$dist, grid$dgp, grid$n, grid$miss,
  vapply(grid$null, function(i) nulls[[i]][1], 0), vapply(grid$null, function(i) nulls[[i]][2], 0))

r <- lapply(list.files(d, "^task_.*\\.rds$", full.names = TRUE), readRDS)
key <- vapply(r, function(x) with(x, fmt(cl$dist, cl$dgp, cl$n, cl$miss, ab[1], ab[2])), "")
sz <- function(p) mean(p < .05, na.rm = TRUE)
# Result schema: v = 2 rows (current harness) keep the naive comparator whenever
# the fits succeeded, so `refused` (scaling refused, p_d4n present) and `failed`
# (a fit failed, p_d4n NA) are separate and the naive size is over all non-failed
# replications ("all"). Earlier rows (no `v`, the 2026-10-09/10 first run) set
# every p-value NA on a refusal, so refusals and failures are not separable and the
# naive size is conditional on scaling succeeding ("cond.").
rows <- lapply(sort(unique(key)), function(k) {
  x <- do.call(rbind, lapply(r[key == k], function(t) {
    res <- t$res
    if (!"v" %in% names(res)) res$v <- 1L
    res
  }))
  v2 <- all(x$v == 2L)
  ok <- !is.na(x$p_d4s)
  data.frame(cell = k, reps = nrow(x), distinct = length(unique(x$rep)),
    complete = nrow(x) == reps_expected && setequal(x$rep, seq_len(reps_expected)) && !anyDuplicated(x$rep),
    unusable = sum(!ok),
    refused = if (v2) sum(!ok & !is.na(x$p_d4n)) else NA_integer_,
    failed_fit = if (v2) sum(is.na(x$p_d4n)) else NA_integer_,
    size_d4s = sz(x$p_d4s), size_d4n = sz(x$p_d4n), naive_basis = if (v2) "all" else "cond.",
    size_d2 = sz(x$p_d2),
    se = sqrt(.05 * .95 / max(1, sum(ok))), cd = mean(x$cd, na.rm = TRUE))
})
tab <- do.call(rbind, rows)
tab$fail_pct <- 100 * tab$unusable / tab$reps
tab$status <- ifelse(!tab$complete, "INCOMPLETE",
  ifelse(tab$fail_pct > max_refused, "UNUSABLE",
    ifelse(tab$size_d4s > bar, "FAIL", "pass")))
print(format(tab[c("cell", "reps", "unusable", "refused", "failed_fit", "fail_pct", "size_d4s", "size_d4n",
  "naive_basis", "size_d2", "se", "cd", "status")], digits = 3), row.names = FALSE)

missing_cells <- setdiff(expected, tab$cell)
extra_cells <- setdiff(tab$cell, expected)
cat(sprintf("\ncells found: %d of %d expected | status: %s\n", nrow(tab), length(expected),
  paste(names(table(tab$status)), table(tab$status), collapse = ", ")))
cat(sprintf("replications without a scaled p-value (refused or failed): %d of %d (%.1f%%); limits: %.0f%% refused per cell, size <= %.3f, %d reps per cell\n",
  sum(tab$unusable), sum(tab$reps), 100 * sum(tab$unusable) / sum(tab$reps), max_refused, bar, reps_expected))
if (length(missing_cells)) cat("missing cells:", length(missing_cells), "e.g.", missing_cells[1], "\n")
if (length(extra_cells)) cat("unexpected cells:", paste(extra_cells, collapse = "; "), "\n")
msgs <- unlist(lapply(r, function(x) x$res$err[!is.na(x$res$err)]))
if (length(msgs)) {
  cat("\nfailure kinds (count):\n")
  print(sort(table(sub("^Fitting the MBCO models failed in [^:]*: ", "", substr(msgs, 1, 130))), decreasing = TRUE)[1:min(4, length(unique(msgs)))])
}

complete_run <- length(missing_cells) == 0 && !length(extra_cells) && all(tab$complete)
verdict <- if (!complete_run) {
  "GATE: INCOMPLETE, not a result (missing or short cells, or unexpected cells)"
} else if (any(tab$status == "FAIL")) {
  "GATE: FAIL (a cell's size exceeds the bar); MLR stays refused"
} else if (any(tab$status == "UNUSABLE")) {
  "GATE: INVALID (a cell has too many refused replications to read its size); MLR stays refused"
} else {
  "GATE: PASS in every cell"
}
cat("\n", verdict, "\n", sep = "")
if (!startsWith(verdict, "GATE: PASS")) quit(status = 1)
