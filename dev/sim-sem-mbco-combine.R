# Combine the array outputs: Rscript dev/sim-sem-mbco-combine.R SIM_OUT
d <- commandArgs(TRUE)[1]
r <- lapply(list.files(d, "^task_.*\\.rds$", full.names = TRUE), readRDS)
key <- vapply(r, function(x) paste(x$cl$dgp, x$cl$n, x$cl$miss, x$ab[1], x$ab[2]), "")
for (k in unique(key)) {
  p <- unlist(lapply(r[key == k], `[[`, "p")); ok <- !is.na(p)
  cat(sprintf("%-34s reps=%4d failed=%2d size@5%%=%.3f  (MC se %.3f)\n", k, sum(ok), sum(!ok),
    mean(p[ok] < .05), sqrt(.05 * .95 / sum(ok))))
}
