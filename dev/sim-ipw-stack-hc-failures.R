# Failing decisive cells of the second IPW coverage gate (SPEC-ipw-stack-hc-gate-2026-10-09.md,
# results section 11). Lists, per weight form, the decisive cells where stacked_hc3 fails C1*,
# C2 or C3, with the shipped path, stacked_hc0, hc1 and hc3 side by side, then the extremes.
#   IPW_DIR=<task-dir> Rscript dev/sim-ipw-stack-hc-failures.R
stopifnot(nzchar(Sys.getenv("IPW_DIR")))
source("dev/sim-ipw-stack-combine.R")
tk <- lapply(list.files(Sys.getenv("IPW_DIR"), full.names = TRUE), readRDS)
res <- do.call(rbind, lapply(tk, function(x) cbind(x$cl[rep(1, nrow(x$res)), c("dgm","n","miss","point")], x$res)))
r <- ipw_summarize(res); tab <- r$tab
L <- function(...) cat(sprintf(...), "\n", sep = "")
dc <- tab[tab$decisive, ]
for (fm in c("sj","uj","spv","sjt")) {
  L("== form %s: decisive cells where stacked_hc3 fails C1*, C2 or C3 (reject at P1-P3, coverage at P4)", fm)
  k <- dc[dc$form == fm & dc$arm == "known_hc3", ]; s3 <- dc[dc$form == fm & dc$arm == "stacked_hc3", ]; s1 <- dc[dc$form == fm & dc$arm == "stacked_hc1", ]; h0 <- dc[dc$form == fm & dc$arm == "stacked_hc0", ]
  key <- function(x) paste(x$dgm, x$n, x$miss, x$point)
  s3 <- s3[match(key(k), key(s3)), ]; s1 <- s1[match(key(k), key(s1)), ]; h0 <- h0[match(key(k), key(h0)), ]
  val <- function(x) ifelse(x$is_null, x$reject, x$cover)
  bad <- which(ifelse(k$is_null, val(s3) - val(k) > DRIFT | val(s3) > SIZE_BAR, val(s3) - val(k) < -DRIFT | val(s3) < COV_BAR))
  for (i in bad) L("  %-5s n=%d miss=%.2f %s: shipped %.3f | hc0 %.3f | hc1 %.3f | HC3 %.3f   (bias b %.3f, ESS %.0f)",
    k$dgm[i], k$n[i], k$miss[i], k$point[i], val(k)[i], val(h0)[i], val(s1)[i], val(s3)[i], k$bias_b[i], k$ess[i])
  if (!length(bad)) L("  none")
}
L("")
L("MAX null size / MIN P4 coverage over decisive cells, by form: shipped | stacked_hc0 | hc1 | hc3")
for (fm in c("uj","sj","sjt","spv")) { f <- function(a) { x <- dc[dc$form==fm & dc$arm==a, ]; sprintf("%.3f / %.3f", max(x$reject[x$is_null]), min(x$cover[!x$is_null])) }
  L("  %-3s %s | %s | %s | %s", fm, f("known_hc3"), f("stacked_hc0"), f("stacked_hc1"), f("stacked_hc3")) }
