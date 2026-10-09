# Local smoke test of the glm calibration harness (SPEC T2): cheap, a few replications.
source("dev/sim-glm-mbco-lib.R")
cells <- glm_cells(); cells$cell <- seq_len(nrow(cells))
stopifnot(nrow(cells) == 132, !anyDuplicated(cells[, c("fam", "n", "miss", "m", "null")]))
cat("cells:", nrow(cells), " by block:", paste(names(table(cells$block)), table(cells$block), collapse = ", "), "\n")
pick <- function(fam, n, miss, m, null) cells[cells$fam == fam & cells$n == n & cells$miss == miss & cells$m == m & cells$null == null, ]
fail <- 0L
ck <- function(label, ok) { cat(if (isTRUE(ok)) "PASS" else "FAIL", label, "\n"); if (!isTRUE(ok)) fail <<- fail + 1L }
# 1. every family returns the recorded fields on a null cell
for (fam in c("gauss_xm", "bin_y", "pois_y", "bin_m")) {
  cl <- pick(fam, 200, .25, 20, 2)
  r <- do.call(rbind, lapply(1:3, function(s) one_glm(cl, 5000 + s)))
  ck(sprintf("%-8s fields present, no refusal (3 reps; p_fixed %s)", fam, paste(sprintf("%.2f", r$p_fixed), collapse = "/")),
    all(c("p_fixed", "p_own", "p_naive", "r4", "nu", "k", "branch", "refused") %in% names(r)) && all(is.na(r$refused)) && !anyNA(r$p_fixed))
}
# 2. gauss_xm reaches k = 2 when the b = th = 0 branch wins (null id 2: a = .3, b = th = 0)
cl <- pick("gauss_xm", 500, .25, 20, 2)
r <- do.call(rbind, lapply(1:4, function(s) one_glm(cl, 5000 + s)))
ck(sprintf("gauss_xm b-null reaches k = 2 (k = %s, branch %s)", paste(r$k, collapse = "/"), paste(r$branch, collapse = "/")),
  all(r$k == 2) && all(r$branch == "b"))
# 3. positive control: the naive pooled test is liberal where D4 is not
cl <- pick("bin_y", 200, .40, 20, 1)
reps <- 120
r <- do.call(rbind, lapply(seq_len(reps), function(s) one_glm(cl, 5000 + s)))
sf <- mean(r$p_fixed < .05, na.rm = TRUE); sn <- mean(r$p_naive < .05, na.rm = TRUE)
ck(sprintf("control: bin_y n=200 40%% (0, .3), %d reps: size fixed %.3f, naive %.3f (naive must exceed fixed; refused %d)",
  reps, sf, sn, sum(!is.na(r$refused))), sn > sf && sn > .065)
quit(status = if (fail) 1L else 0L)
