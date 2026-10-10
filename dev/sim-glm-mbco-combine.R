# Combine the array outputs and evaluate the gate criteria of
# SPEC-glm-mbco-calibration-2026-10-09.md:  Rscript dev/sim-glm-mbco-combine.R SIM_OUT
source("dev/sim-glm-mbco-lib.R")
d <- commandArgs(TRUE)[1]
r <- lapply(list.files(d, "^task_.*\\.rds$", full.names = TRUE), readRDS)
stopifnot(length(r) > 0)
rows <- do.call(rbind, lapply(r, function(x) cbind(cell = x$cell, x$res)))
cells <- glm_cells(); cells$cell <- seq_len(nrow(cells))
sz <- function(p) if (sum(!is.na(p))) mean(p < .05, na.rm = TRUE) else NA_real_
tab <- do.call(rbind, lapply(split(rows, rows$cell), function(g) {
  c0 <- cells[cells$cell == g$cell[1], ]
  data.frame(cell = c0$cell, block = c0$block, fam = c0$fam, n = c0$n, miss = c0$miss, m = c0$m,
    null = c0$null, reps = nrow(g), refused = mean(!is.na(g$refused)),
    fixed = sz(g$p_fixed), own = sz(g$p_own), naive = sz(g$p_naive),
    own_na = mean(is.na(g$p_own) & !is.na(g$p_fixed)),
    se = sqrt(.05 * .95 / max(1, sum(!is.na(g$p_fixed)))), k = mean(g$k, na.rm = TRUE),
    r4 = mean(g$r4, na.rm = TRUE), stringsAsFactors = FALSE)
}))
tab$kind <- ifelse(tab$null == 6, "power", ifelse(tab$null %in% 1:2, "single-null", "other-null"))
options(width = 200); print(format(tab, digits = 3), row.names = FALSE)

nul <- tab[tab$null < 6, ]
chk <- function(label, ok, detail = "") cat(sprintf("%-4s %s %s\n", if (is.na(ok)) "n/a" else if (ok) "PASS" else "FAIL", label, detail))
cat("\n== Criteria\n")
chk("C1 size <= 6.5% in every null cell (fixed)", all(nul$fixed <= .065, na.rm = TRUE),
  sprintf("(max %.3f over %d null cells present)", max(nul$fixed, na.rm = TRUE), nrow(nul)))
sk <- nul[nul$block == "smallk", ]
chk("C2 size <= 6.5% at m = 5, 10", if (nrow(sk)) all(sk$fixed <= .065, na.rm = TRUE) else NA,
  if (nrow(sk)) sprintf("(max %.3f)", max(sk$fixed, na.rm = TRUE)) else "")
pw <- tab[tab$null == 6 & tab$block == "main" & tab$n == 500, ]
chk("C3 power >= 50% in n = 500 main cells", if (nrow(pw)) all(pw$fixed >= .5, na.rm = TRUE) else NA,
  if (nrow(pw)) sprintf("(min %.3f)", min(pw$fixed, na.rm = TRUE)) else "")
rf <- tab[tab$block %in% c("main", "smallk"), ]
chk("C4 refusal share <= 1% (main, small K)", if (nrow(rf)) all(rf$refused <= .01) else NA,
  if (nrow(rf)) sprintf("(max %.3f)", max(rf$refused)) else "")
ct <- tab[tab$fam == "bin_y" & tab$n == 200 & tab$miss == .4 & tab$m == 20 & tab$null %in% 1:2, ]
chk("C5 positive control: naive pooling is liberal (> 6.5%) in bin_y n=200, 40%", if (nrow(ct)) all(ct$naive > .065, na.rm = TRUE) else NA,
  if (nrow(ct)) paste0("(naive ", paste(sprintf("%.3f", ct$naive), collapse = ", "), "); a void result here voids the run") else "")
cat("C6 ariv = 'own' is reported (column `own`; `own_na` = share of replications where own returned no p-value because the branches mixed; own sizes are conditional on those being absent).\n")
gs <- nul[nul$block == "gauss", ]
if (nrow(gs)) chk("C7 plain Gaussian, k = 1 (SPEC section 10): own and fixed size <= 6.5% in every cell, own never errors",
  all(gs$own <= .065, na.rm = TRUE) && all(gs$fixed <= .065, na.rm = TRUE) && all(gs$own_na == 0),
  sprintf("(max own %.3f, max fixed %.3f, max own_na %.3f over %d cells)", max(gs$own, na.rm = TRUE), max(gs$fixed, na.rm = TRUE), max(gs$own_na), nrow(gs)))
