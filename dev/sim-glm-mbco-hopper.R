# One SLURM array task of the glm-engine MBCO calibration gate
# (SPEC-glm-mbco-calibration-2026-10-09.md). Task id t -> cell (t - 1) %/% CHUNKS + 1,
# chunk (t - 1) %% CHUNKS. Single core.
# Env: SIM_OUT (output dir), CHUNKS (default 3), REPS (per cell, default 1000),
#      ONLY_CELLS (optional comma list of cell indices; task t then maps into that
#      list, for pilots), SIM_INSTALLED=1 on hopper.
source("dev/sim-glm-mbco-lib.R")
out <- Sys.getenv("SIM_OUT", "sim-out"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
chunks <- as.integer(Sys.getenv("CHUNKS", "3")); reps <- as.integer(Sys.getenv("REPS", "1000"))
cells <- glm_cells()
only <- Sys.getenv("ONLY_CELLS", "")
pick <- if (nzchar(only)) as.integer(strsplit(only, ",")[[1]]) else seq_len(nrow(cells))
t <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))
stopifnot(t >= 1, t <= length(pick) * chunks)
ci <- pick[(t - 1) %/% chunks + 1]; k <- (t - 1) %% chunks
cl <- cells[ci, ]
idx <- split(seq_len(reps), rep_len(seq_len(chunks), reps))[[k + 1]]
t0 <- Sys.time()
res <- do.call(rbind, lapply(idx, function(s) one_glm(cl, 5000 + s)))
res$rep <- idx
saveRDS(list(task = t, cell = ci, chunk = k, cl = cl, res = res,
  secs = as.numeric(difftime(Sys.time(), t0, units = "secs"))),
  file.path(out, sprintf("task_%04d.rds", t)))
cat(sprintf("task %d: cell %d %s n=%d miss=%.2f m=%d null=%d reps=%d refused=%d size_fixed=%.3f [%.0fs]\n",
  t, ci, cl$fam, cl$n, cl$miss, cl$m, cl$null, nrow(res), sum(!is.na(res$refused)),
  mean(res$p_fixed < .05, na.rm = TRUE), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
