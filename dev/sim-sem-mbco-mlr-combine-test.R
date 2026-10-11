# Planted-defect test of the gate combiner: a synthetic complete run must PASS
# (exit 0); each defect must be caught with exit 1 and the right verdict.
#   Rscript dev/sim-sem-mbco-mlr-combine-test.R        (from the repo root)
nulls <- list(c(0, .3), c(.3, 0), c(0, 0), c(0, .1), c(.1, 0))
grid <- expand.grid(dist = c("skewed", "heavy"), dgp = c("observed", "latent"), n = c(200L, 500L),
  miss = c(0.25, 0.40), null = seq_along(nulls), stringsAsFactors = FALSE)
make_run <- function(dir, size = 0.05, bad_cell = NULL, bad_size = NULL, bad_fail = 0) {
  dir.create(dir, recursive = TRUE)
  set.seed(1)
  for (t in seq_len(nrow(grid) * 4)) {
    cell <- (t - 1) %/% 4 + 1; k <- (t - 1) %% 4
    idx <- split(seq_len(1000), rep_len(seq_len(4), 1000))[[k + 1]]
    sz <- if (!is.null(bad_cell) && cell == bad_cell) bad_size else size
    p <- ifelse(seq_along(idx) <= round(sz * length(idx)), 0.01, 0.5)
    res <- data.frame(rep = idx, p_d4s = p, p_d4n = p, p_d2 = p, cd = 1, k = 1, r4 = 0.1, err = NA_character_)
    if (!is.null(bad_cell) && cell == bad_cell && bad_fail > 0) {
      nf <- round(bad_fail * length(idx))
      res[seq_len(nf), c("p_d4s", "p_d4n", "p_d2", "cd")] <- NA
      res$err[seq_len(nf)] <- "Fitting the MBCO models failed in imputation 1: the scaled difference test for the a = 0 null is undefined: x"
    }
    saveRDS(list(task = t, cell = cell, chunk = k, cl = grid[cell, ], ab = nulls[[grid$null[cell]]], res = res),
      file.path(dir, sprintf("task_%04d.rds", t)))
  }
}
run <- function(dir, ...) {
  out <- suppressWarnings(system2("Rscript", c("dev/sim-sem-mbco-mlr-combine.R", dir, ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(out, "status") %||% 0L, verdict = grep("^GATE:", out, value = TRUE))
}
`%||%` <- function(a, b) if (is.null(a)) b else a
ok <- function(cond, msg) { cat(if (isTRUE(cond)) "PASS " else "FAIL ", msg, "\n", sep = ""); if (!isTRUE(cond)) quit(status = 1) }
tmp <- tempfile("combine-test"); dir.create(tmp)

d1 <- file.path(tmp, "good"); make_run(d1)
r <- run(d1); ok(r$status == 0 && grepl("PASS in every cell", r$verdict), "a complete clean run passes, exit 0")

d2 <- file.path(tmp, "missing"); make_run(d2); unlink(file.path(d2, "task_0007.rds"))
r <- run(d2); ok(r$status == 1 && grepl("INCOMPLETE", r$verdict), "a missing task file is INCOMPLETE, exit 1")

d3 <- file.path(tmp, "dup"); make_run(d3)
x <- readRDS(file.path(d3, "task_0001.rds")); x$res$rep[1] <- x$res$rep[2]; saveRDS(x, file.path(d3, "task_0001.rds"))
r <- run(d3); ok(r$status == 1 && grepl("INCOMPLETE", r$verdict), "a duplicated replication id is INCOMPLETE, exit 1")

d4 <- file.path(tmp, "oversize"); make_run(d4, bad_cell = 5, bad_size = 0.07)
r <- run(d4); ok(r$status == 1 && grepl("FAIL", r$verdict) && !grepl("INCOMPLETE|INVALID", r$verdict), "a cell at size 0.07 is a FAIL, exit 1")

d5 <- file.path(tmp, "refused"); make_run(d5, bad_cell = 9, bad_size = 0.04, bad_fail = 0.07)
r <- run(d5); ok(r$status == 1 && grepl("INVALID", r$verdict), "a cell with 7% refused is INVALID, exit 1")

d6 <- file.path(tmp, "pilot"); make_run(d6)
for (f in list.files(d6, full.names = TRUE)[-(1:12)]) unlink(f)
r <- run(d6, "1000"); ok(r$status == 1 && !grepl("PASS", r$verdict), "a partial run can never print PASS")
cat("combiner tests OK\n")
