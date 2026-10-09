# One SLURM array task of the ML calibration gate (SPEC-sem-mbco-2026-10-08.md, T8a).
# Task id t -> cell (t - 1) %/% CHUNKS + 1, chunk (t - 1) %% CHUNKS. Single core.
# Env: SIM_OUT (output dir), CHUNKS (default 4), REPS (per cell, default 1000),
#      MISS (default 0.40), SIM_NS (default "200,500"), SIM_INSTALLED=1 on hopper.
source("dev/sim-sem-mbco-lib.R")
out <- Sys.getenv("SIM_OUT", "sim-out"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
chunks <- as.integer(Sys.getenv("CHUNKS", "4")); reps <- as.integer(Sys.getenv("REPS", "1000"))
miss <- as.numeric(Sys.getenv("MISS", "0.40"))
ns <- as.integer(strsplit(Sys.getenv("SIM_NS", "200,500"), ",")[[1]])
cells <- expand.grid(dgp = c("observed", "latent"), n = ns, miss = miss, null = seq_along(nulls),
  stringsAsFactors = FALSE)
t <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))
stopifnot(t >= 1, t <= nrow(cells) * chunks)
cl <- cells[(t - 1) %/% chunks + 1, ]; k <- (t - 1) %% chunks
ab <- nulls[[cl$null]]
idx <- split(seq_len(reps), rep_len(seq_len(chunks), reps))[[k + 1]]
t0 <- Sys.time()
p <- vapply(idx, function(s) one(cl$dgp, cl$n, ab[1], ab[2], cl$miss, 5000 + s), numeric(1))
saveRDS(list(task = t, cell = (t - 1) %/% chunks + 1, chunk = k, cl = cl, ab = ab, reps = idx, p = p,
  secs = as.numeric(difftime(Sys.time(), t0, units = "secs"))),
  file.path(out, sprintf("task_%04d.rds", t)))
cat(sprintf("task %d: %s n=%d miss=%.2f (%.1f,%.1f) reps=%d failed=%d size=%.3f [%.0fs]\n", t, cl$dgp, cl$n,
  cl$miss, ab[1], ab[2], length(p), sum(is.na(p)), mean(p < .05, na.rm = TRUE),
  as.numeric(difftime(Sys.time(), t0, units = "secs"))))
