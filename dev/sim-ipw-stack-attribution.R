# Attribution analysis for the IPW stack coverage gate
# (SPEC-ipw-stack-coverage-2026-10-09.md section 13). Reads the task files of a full run.
#   IPW_DIR=<task-dir> Rscript dev/sim-ipw-stack-attribution.R
# Prints: P4 coverage and null size by arm, bias of a and b by weight form, cells
# failing C1 per arm, and the paired decomposition (weight estimation vs HC0/HC3).
dir <- Sys.getenv("IPW_DIR"); stopifnot(nzchar(dir))
source("dev/sim-ipw-stack-combine.R")
tk <- lapply(list.files(dir, "^task_.*\\.rds$", full.names = TRUE), readRDS)
res <- do.call(rbind, lapply(tk, function(x) cbind(x$cl[rep(1, nrow(x$res)), c("dgm","n","miss","point")], x$res)))
all_res <- res
tab <- ipw_summarize(res)$tab; tab <- tab[tab$arm != "model_se", ]
L <- function(...) cat(sprintf(...), "\n", sep = "")
L("P4 COVERAGE (bar 0.935), all forms: arm = known_hc3 / known_hc0 / stacked")
for (fm in c("uj","sj","sjt","spv")) for (dg in c("std","aux","auxm")) for (n in c(200,500)) for (m in c(.25,.40)) {
  g <- function(a) tab$cover[tab$form==fm & tab$dgm==dg & tab$n==n & tab$miss==m & tab$point=="P4" & tab$arm==a]
  L("  %-3s %-4s n=%d miss=%.2f  %.3f / %.3f / %.3f%s", fm, dg, n, m, g("known_hc3"), g("known_hc0"), g("stacked"), if (g("stacked") < .935) "  <-stacked fails" else "")
}
L("")
L("MAX NULL SIZE (P1-P3) by form: known_hc3 / known_hc0 / stacked")
for (fm in c("uj","sj","sjt","spv")) { g <- function(a) max(tab$reject[tab$form==fm & tab$point!="P4" & tab$arm==a]); L("  %-3s %.3f / %.3f / %.3f", fm, g("known_hc3"), g("known_hc0"), g("stacked")) }
L("")
L("BIAS AND SPREAD of a*b at P4 (estimates are identical across arms), form sj")
for (cond in list(c("auxm",500,.40), c("auxm",200,.40), c("std",500,.40))) {
  x <- res[res$dgm==cond[1] & res$n==as.numeric(cond[2]) & res$miss==as.numeric(cond[3]) & res$point=="P4" & res$form=="sj" & res$arm=="stacked", ]
  ab <- x$a * x$b
  L("  %s n=%s miss=%s: mean a %.3f (nominal .3), mean b %.3f, mean ab %.4f (nominal .09), sd(ab) %.4f, median width %.3f, implied sd from width %.4f",
    cond[1], cond[2], cond[3], mean(x$a), mean(x$b), mean(ab), sd(ab), median(x$width), median(x$width)/(2*1.96))
}

res <- all_res[all_res$arm == "stacked" & all_res$point == "P4", ]
L <- function(...) cat(sprintf(...), "\n", sep = "")
L("MEAN b (nominal 0.30) and mean ab (nominal 0.09) at P4, by DGM / n / miss / form")
for (dg in c("std","aux","auxm")) for (m in c(.25,.40)) for (n in c(200,500)) {
  s <- sapply(c("uj","sj","sjt","spv"), function(fm) { x <- res[res$dgm==dg & res$miss==m & res$n==n & res$form==fm, ]; sprintf("%s b=%.3f ab=%.3f", fm, mean(x$b), mean(x$a*x$b)) })
  L("  %-4s miss=%.2f n=%d  %s", dg, m, n, paste(s, collapse = " | "))
}
x <- res[res$dgm=="auxm" & res$n==500 & res$miss==.40 & res$form=="sj", ]
L("")
L("auxm n=500 miss=.40 sj: median(a*b) %.4f, sd(a*b) %.4f; share of reps with b < 0.2: %.3f; share with b > 0.4: %.3f", median(x$a*x$b), sd(x$a*x$b), mean(x$b<.2), mean(x$b>.4))

L <- function(...) cat(sprintf(...), "\n", sep = "")
fails <- function(fm, arm, cells) { x <- tab[tab$form == fm & tab$arm == arm, ]; x <- x[paste(x$dgm) %in% cells, ]
  sum((x$point != "P4" & x$reject > SIZE_BAR) | (x$point == "P4" & x$cover < COV_BAR)) }
L("CELLS FAILING C1 (of 12 per DGM; null size > 0.065 or P4 coverage < 0.935)   known_hc3 / known_hc0 / stacked")
for (fm in c("uj","sj","sjt","spv")) for (dg in c("std","aux","auxm"))
  L("  %-3s %-4s  %d / %d / %d", fm, dg, fails(fm,"known_hc3",dg), fails(fm,"known_hc0",dg), fails(fm,"stacked",dg))
L("")
L("MEAN PAIRED DIFFERENCES over the cells (form sj): size at P1-P3 and coverage at P4")
for (dg in c("std","aux","auxm")) {
  g <- function(a, pt) tab[tab$form=="sj" & tab$dgm==dg & tab$arm==a & (if (pt) tab$point=="P4" else tab$point!="P4"), ]
  L("  %-4s weight estimation (stacked - hc0): size %+.4f, coverage %+.4f | small-sample correction (hc0 - hc3): size %+.4f, coverage %+.4f",
    dg, mean(g("stacked",F)$reject - g("known_hc0",F)$reject), mean(g("stacked",T)$cover - g("known_hc0",T)$cover),
    mean(g("known_hc0",F)$reject - g("known_hc3",F)$reject), mean(g("known_hc0",T)$cover - g("known_hc3",T)$cover))
}
L("")
L("width ratio stacked/known_hc3 (median over cells), sj: %.3f; stacked/known_hc0: see paired table", median(ipw_summarize(all_res)$pair$width_ratio[ipw_summarize(all_res)$pair$form=="sj"]))

