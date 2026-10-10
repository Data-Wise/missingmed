# Combine the MLR gate's array outputs and apply the section 5 criterion:
#   Rscript dev/sim-sem-mbco-mlr-combine.R SIM_OUT
# Per cell: size at the 5% level of the scaled D4 (the statistic under test), the
# naive D4 and D2 (comparators), failed replications, and the NA share of every
# p-value column (a dropped replication is not a pass; read size next to it).
d <- commandArgs(TRUE)[1]
r <- lapply(list.files(d, "^task_.*\\.rds$", full.names = TRUE), readRDS)
key <- vapply(r, function(x) with(x, sprintf("%-6s %-8s n=%d miss=%.2f (%.1f,%.1f)", cl$dist, cl$dgp, cl$n,
  cl$miss, ab[1], ab[2])), "")
sz <- function(p) mean(p < .05, na.rm = TRUE)
rows <- lapply(sort(unique(key)), function(k) {
  x <- do.call(rbind, lapply(r[key == k], `[[`, "res"))
  ok <- !is.na(x$p_d4s)
  data.frame(cell = k, reps = nrow(x), failed = sum(!ok), na_d2 = sum(is.na(x$p_d2) & ok),
    size_d4s = sz(x$p_d4s), size_d4n = sz(x$p_d4n), size_d2 = sz(x$p_d2),
    se = sqrt(.05 * .95 / max(1, sum(ok))), cd = mean(x$cd, na.rm = TRUE))
})
tab <- do.call(rbind, rows)
tab$pass <- tab$size_d4s <= 0.065
tab$fail_pct <- 100 * tab$failed / tab$reps
print(format(tab, digits = 3), row.names = FALSE)
cat(sprintf("\ncells: %d | pass (size <= 0.065): %d | failed replications: %d of %d (%.1f%%)\n",
  nrow(tab), sum(tab$pass), sum(tab$failed), sum(tab$reps), 100 * sum(tab$failed) / sum(tab$reps)))
msgs <- unlist(lapply(r, function(x) x$res$err[!is.na(x$res$err)]))
if (length(msgs)) {
  cat("\nfailure messages (count):\n")
  print(sort(table(substr(msgs, 1, 110)), decreasing = TRUE))
}
hi <- tab$cell[tab$fail_pct > 5]
if (length(hi)) {
  cat("\ncells with more than 5% refused/failed replications (size is conditional on success; read with care):\n")
  cat(paste0("  ", hi, collapse = "\n"), "\n")
}
cat(if (all(tab$pass)) "\nGATE: PASS in every cell\n" else "\nGATE: FAIL, cells above 0.065 listed (pass = FALSE); MLR stays refused\n")
