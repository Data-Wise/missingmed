# One SLURM array task of the missingness-model gate
# (SPEC-ipw-missingness-default-2026-10-09.md). Task id t -> cell (t - 1) %/% CHUNKS + 1,
# chunk (t - 1) %% CHUNKS. Single core.
# Env: SIM_OUT (output dir), CHUNKS (default 2), REPS (per cell, default 1000),
#      ONLY_CELLS (optional comma list of cell indices; task t then maps into that list,
#      for pilots). Needs no missingmed install: the weights are computed in the lib.
source("dev/sim-ipw-mech-lib.R")
out <- Sys.getenv("SIM_OUT", "sim-out-mech"); dir.create(out, showWarnings = FALSE, recursive = TRUE)
chunks <- as.integer(Sys.getenv("CHUNKS", "2")); reps <- as.integer(Sys.getenv("REPS", "1000"))
cells <- readRDS("dev/sim-ipw-mech-cells.rds")   # the stored cells, not regenerated
stopifnot(isTRUE(all.equal(cells, mech_cells())))
only <- Sys.getenv("ONLY_CELLS", "")
pick <- if (nzchar(only)) as.integer(strsplit(only, ",")[[1]]) else seq_len(nrow(cells))
t <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))
stopifnot(t >= 1, t <= length(pick) * chunks)
ci <- pick[(t - 1) %/% chunks + 1]; k <- (t - 1) %% chunks
cl <- cells[ci, ]
idx <- split(seq_len(reps), rep_len(seq_len(chunks), reps))[[k + 1]]
t0 <- Sys.time()
res <- do.call(rbind, lapply(idx, function(s) { r <- one_mech(cl, 5000 + 100000 * ci + s); r$rep <- s; r }))
saveRDS(list(task = t, cell = ci, chunk = k, cl = cl, res = res,
  secs = as.numeric(difftime(Sys.time(), t0, units = "secs"))),
  file.path(out, sprintf("task_%04d.rds", t)))
sq <- res[res$form == "seq", ]
cat(sprintf("task %d: cell %d %s %s n=%d miss=%.2f %s reps=%d errors=%d bias_b(seq)=%+.4f [%.0fs]\n",
  t, ci, cl$mech, cl$dgm, cl$n, cl$miss, cl$point, length(idx), sum(!is.na(res$error)),
  mean(sq$b - sq$truth_b, na.rm = TRUE), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
