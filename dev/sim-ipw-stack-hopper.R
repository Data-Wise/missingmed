# One SLURM array task of the IPW stack coverage gate
# (SPEC-ipw-stack-hc-gate-2026-10-09.md). Task id t -> cell (t - 1) %/% CHUNKS + 1,
# chunk (t - 1) %% CHUNKS. Single core.
# Env: SIM_OUT (output dir), CHUNKS (default 4), REPS (per cell, default 2000),
#      ONLY_CELLS (optional comma list of cell indices; task t then maps into that
#      list, for pilots), SIM_INSTALLED=1 on hopper.
source("dev/sim-ipw-stack-lib.R")
out <- Sys.getenv("SIM_OUT", "sim-out-ipw"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
chunks <- as.integer(Sys.getenv("CHUNKS", "4")); reps <- as.integer(Sys.getenv("REPS", "2000"))
cells <- ipw_cells()
only <- Sys.getenv("ONLY_CELLS", "")
pick <- if (nzchar(only)) as.integer(strsplit(only, ",")[[1]]) else seq_len(nrow(cells))
t <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))
stopifnot(t >= 1, t <= length(pick) * chunks)
ci <- pick[(t - 1) %/% chunks + 1]; k <- (t - 1) %% chunks
cl <- cells[ci, ]
idx <- split(seq_len(reps), rep_len(seq_len(chunks), reps))[[k + 1]]
t0 <- Sys.time()
res <- do.call(rbind, lapply(idx, function(s) { r <- one_ipw(cl, 5000 + 100000 * ci + s); r$rep <- s; r }))
saveRDS(list(task = t, cell = ci, chunk = k, cl = cl, res = res,
  version = as.character(utils::packageVersion("missingmed")),
  secs = as.numeric(difftime(Sys.time(), t0, units = "secs"))),
  file.path(out, sprintf("task_%04d.rds", t)))
cl_form <- ipw_decisive[[cl$dgm]][1]
st <- res[res$arm == "stacked_hc3" & res$form == cl_form, ]
cat(sprintf("task %d: cell %d %s n=%d miss=%.2f %s reps=%d errors=%d reject0(stacked_hc3, %s)=%.3f [%.0fs]\n",
  t, ci, cl$dgm, cl$n, cl$miss, cl$point, length(idx), sum(!is.na(res$error)), cl_form,
  mean(st$reject0, na.rm = TRUE), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
