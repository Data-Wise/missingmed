# Criteria C1-C6, controls and the per-weight-form decision for the second IPW
# coverage gate (SPEC-ipw-stack-hc-gate-2026-10-09.md, sections 2-3).
#   Rscript dev/sim-ipw-stack-combine.R <task-dir>     summarize a run
#   Rscript dev/sim-ipw-stack-combine.R --selftest     planted-outcome test of the logic
# Not part of the package build.
SIZE_BAR <- .065; COV_BAR <- .935; DRIFT <- .010; DROP_BAR <- .01
DECISIVE <- list(std = "spv", aux = "spv", auxm = "spv",
  stdj = c("uj", "sj", "sjt"), auxj = c("uj", "sj", "sjt"), auxmj = c("uj", "sj", "sjt"))
VARIANTS <- c("stacked_hc3", "stacked_hc1")   # primary first (spec section 3)

# `res`: one row per (cell, rep, form, arm): cell columns dgm, n, miss, point plus the
# columns of one_ipw(). Returns the per-cell table, paired comparisons, per-form
# criteria and decisions, the control-2 check and bias-limited cells.
ipw_summarize <- function(res) {
  res$cellkey <- paste(res$dgm, res$n, res$miss, res$point)
  res$ok <- is.na(res$error) & !is.na(res$lo)
  rows <- lapply(split(res, paste(res$cellkey, res$form, res$arm)), function(x) {
    data.frame(dgm = x$dgm[1], n = x$n[1], miss = x$miss[1], point = x$point[1], form = x$form[1],
      arm = x$arm[1], reps = nrow(x), dropped = mean(!x$ok),
      leverage_err = mean(grepl("leverage", x$error)),
      reject = mean(x$reject0[x$ok]), cover = mean(x$cover[x$ok]),
      width = stats::median(x$width[x$ok]),
      bias_a = mean(x$a - x$truth_a, na.rm = TRUE), bias_b = mean(x$b - x$truth_b, na.rm = TRUE),
      bias_ab = mean(x$a * x$b - x$truth, na.rm = TRUE),
      ess = stats::median(x$ess, na.rm = TRUE), max_w_share = stats::median(x$max_w_share, na.rm = TRUE),
      stringsAsFactors = FALSE)
  })
  tab <- do.call(rbind, rows); rownames(tab) <- NULL
  tab$is_null <- tab$point != "P4"
  tab$decisive <- mapply(function(d, f) f %in% DECISIVE[[d]], tab$dgm, tab$form)
  tab$conditional <- tab$dropped > DROP_BAR
  # paired stacked_hc3 vs known_hc3 (same replications)
  sub <- res[res$arm %in% c("stacked_hc3", "known_hc3"), ]
  pair <- do.call(rbind, lapply(split(sub, paste(sub$cellkey, sub$form)), function(x) {
    s <- x[x$arm == "stacked_hc3", ]; k <- x[x$arm == "known_hc3", ]
    m <- merge(s[, c("rep", "reject0", "width", "ok")], k[, c("rep", "reject0", "width", "ok")], by = "rep", suffixes = c("_s", "_k"))
    m <- m[m$ok_s & m$ok_k, ]
    n01 <- sum(m$reject0_s & !m$reject0_k); n10 <- sum(!m$reject0_s & m$reject0_k)
    data.frame(dgm = x$dgm[1], n = x$n[1], miss = x$miss[1], point = x$point[1], form = x$form[1],
      n_stacked_only = n01, n_known_only = n10,
      mcnemar_p = if (n01 + n10 > 0) stats::binom.test(n01, n01 + n10, .5)$p.value else 1,
      width_ratio = stats::median(m$width_s / m$width_k), stringsAsFactors = FALSE)
  }))
  rownames(pair) <- NULL
  # criteria per form and variant, decisive cells only
  key <- c("dgm", "n", "miss", "point")
  kn <- tab[tab$arm == "known_hc3" & tab$decisive, ]
  crit <- list(); bias_limited <- list()
  for (fm in sort(unique(tab$form))) for (v in VARIANTS) {
    st <- tab[tab$arm == v & tab$form == fm & tab$decisive, ]
    kk <- kn[kn$form == fm, ]
    if (!nrow(st)) next
    mm <- merge(st, kk, by = key, suffixes = c("_s", "_k"))
    pass1 <- function(rej, cov, nul) ifelse(nul, rej <= SIZE_BAR, cov >= COV_BAR)
    c1_s <- pass1(mm$reject_s, mm$cover_s, mm$is_null_s)
    c1_k <- pass1(mm$reject_k, mm$cover_k, mm$is_null_s)
    near <- ifelse(mm$is_null_s, mm$reject_s - mm$reject_k <= DRIFT, mm$cover_s - mm$cover_k >= -DRIFT)
    c1star_cell <- c1_s %in% TRUE | (!(c1_k %in% TRUE) & near %in% TRUE)
    limited <- !(c1_k %in% TRUE) & c1star_cell & !(c1_s %in% TRUE)
    c2_cell <- ifelse(mm$is_null_s, mm$reject_s - mm$reject_k <= DRIFT, mm$cover_s - mm$cover_k >= -DRIFT)
    c3_cell <- ifelse(!mm$is_null_s, mm$reject_s - mm$reject_k >= -DRIFT, TRUE)
    cond <- any(mm$conditional_s | mm$conditional_k)
    # NA (an arm with every replication dropped) is a FAIL, never a crash
    c1 <- all(c1_s %in% TRUE); c1star <- all(c1star_cell %in% TRUE)
    c2 <- all(c2_cell %in% TRUE); c3 <- all(c3_cell %in% TRUE)
    viable <- c1star && c2 && c3 && !cond
    failing <- mm[!(c1star_cell %in% TRUE) | !(c2_cell %in% TRUE) | !(c3_cell %in% TRUE), key]
    crit[[length(crit) + 1L]] <- data.frame(form = fm, variant = v, decisive_cells = nrow(mm), C1 = c1, C1star = c1star,
      C2 = c2, C3 = c3, conditional = cond, viable = viable, failing_cells = nrow(failing), stringsAsFactors = FALSE)
    if (any(limited)) bias_limited[[length(bias_limited) + 1L]] <- cbind(form = fm, variant = v, mm[limited, key])
  }
  crit <- do.call(rbind, crit); rownames(crit) <- NULL
  decision <- do.call(rbind, lapply(split(crit, crit$form), function(x) {
    vv <- x$viable[match(VARIANTS, x$variant)] %in% TRUE
    data.frame(form = x$form[1], decision = if (vv[1]) "viable: hc3" else if (vv[2]) "viable: hc1" else "none",
      stringsAsFactors = FALSE)
  }))
  rownames(decision) <- NULL
  # control 2: the model-based arm shows a detectable size distortion in an aux* null cell
  ms <- tab[tab$arm == "model_se" & grepl("^aux", tab$dgm) & tab$is_null, ]
  list(tab = tab, pair = pair, crit = crit, decision = decision,
    control2 = nrow(ms) > 0 && any(ms$reject > SIZE_BAR | ms$reject < .035),
    bias_limited = if (length(bias_limited)) do.call(rbind, bias_limited) else NULL)
}

ipw_report <- function(r) {
  cat(sprintf("CONTROL 2 (model-based arm shows a detectable size distortion in an aux* null cell): %s\n",
    if (r$control2) "PASS" else "FAIL - the grid cannot see a wrong variance; results below do not count"))
  cat("\nDECISION PER WEIGHT FORM (decisive cells only; variant rule: hc3 primary, hc1 secondary)\n")
  print(r$decision, row.names = FALSE)
  cat("\nCRITERIA PER FORM AND VARIANT\n"); print(r$crit, row.names = FALSE)
  cat("\nBIAS-LIMITED DECISIVE CELLS (the shipped path also fails C1; stacked within 0.010)\n")
  if (is.null(r$bias_limited)) cat("none\n") else print(r$bias_limited, row.names = FALSE)
  cat("\nFAILURE SHARES (C5): arms with more than 1% dropped replications (sizes there are conditional)\n")
  d <- r$tab[r$tab$conditional, c("dgm", "n", "miss", "point", "form", "arm", "dropped", "leverage_err")]
  if (nrow(d)) print(d, row.names = FALSE) else cat("none\n")
  cat("\nPAIRED stacked_hc3 vs known_hc3, decisive cells with McNemar p < 0.01\n")
  dec <- r$tab[r$tab$arm == "known_hc3" & r$tab$decisive, c("dgm", "n", "miss", "point", "form")]
  p <- merge(r$pair, dec, by = c("dgm", "n", "miss", "point", "form")); p <- p[p$mcnemar_p < .01, ]
  if (nrow(p)) print(p, row.names = FALSE, digits = 3) else cat("none\n")
  cat("\nC6: BIAS OF b AND WEIGHT CONCENTRATION AT P4 (form = the DGM's first decisive form, arm known_hc3)\n")
  b <- r$tab[r$tab$arm == "known_hc3" & r$tab$point == "P4" & r$tab$decisive, c("dgm", "n", "miss", "form", "bias_a", "bias_b", "bias_ab", "ess", "max_w_share")]
  b <- b[order(b$dgm, b$form, b$n, b$miss), ]; print(b, row.names = FALSE, digits = 3)
  cat("\nSIZE / COVERAGE TABLE, decisive cells (reject at P1-P3, coverage at P4)\n")
  t <- r$tab[r$tab$decisive & r$tab$arm != "model_se", c("dgm", "n", "miss", "point", "form", "arm", "reject", "cover", "width", "dropped")]
  print(t[order(t$dgm, t$form, t$n, t$miss, t$point, t$arm), ], row.names = FALSE, digits = 3)
}

# Deterministic synthetic results: each arm in each cell gets exactly round(p * R) rejections
# (and covers), paired across arms by one shared permutation, so no Monte-Carlo noise.
selftest <- function() {
  R <- 400
  cells <- expand.grid(dgm = names(DECISIVE), n = c(200, 500), miss = c(.25, .40),
    point = c("P1", "P2", "P3", "P4"), stringsAsFactors = FALSE)
  arms <- c("known_hc3", "known_hc0", "stacked_hc0", "stacked_hc1", "stacked_hc3", "model_se")
  mk <- function(over = function(...) NULL, drop = function(...) FALSE) {
    out <- vector("list", nrow(cells) * 4 * 6); k <- 0L
    perm <- sample.int(R)
    for (i in seq_len(nrow(cells))) for (fm in c("uj", "sj", "sjt", "spv")) for (arm in arms) {
      if (arm == "model_se" && fm != "uj") next
      cl <- cells[i, ]; nul <- cl$point != "P4"
      p <- if (nul) .045 else .60                 # rejection rate
      cv <- if (nul) 1 - p else .95               # coverage
      if (arm == "model_se" && grepl("^aux", cl$dgm) && nul) p <- .12   # the control arm is visibly wrong by default
      o <- over(cl, fm, arm); if (!is.null(o)) { if (!is.null(o$rej)) p <- o$rej; if (!is.null(o$cov)) cv <- o$cov }
      rej <- perm <= round(p * R); cov <- perm <= round(cv * R)
      err <- rep(NA_character_, R); if (drop(cl, fm, arm)) err[] <- "stacked variance failed"
      k <- k + 1L
      out[[k]] <- data.frame(cl, form = fm, arm = arm, rep = seq_len(R), error = err, row.names = NULL,
        a = .3, b = .3, lo = ifelse(rej, .1, -.1), hi = ifelse(rej, .3, .1), pd = 1, reject0 = rej, cover = cov,
        width = .2, truth = .09, truth_a = .3, truth_b = .3, ess = 100, max_w_share = .05, stringsAsFactors = FALSE)
    }
    do.call(rbind, out[seq_len(k)])
  }
  dec <- function(r, f) r$decision$decision[r$decision$form == f]
  # (1) clean data: every form viable with the primary variant
  r1 <- ipw_summarize(mk())
  stopifnot(r1$control2, all(r1$decision$decision == "viable: hc3"), all(r1$crit$viable), is.null(r1$bias_limited))
  # (2) primary fails in one decisive cell of sj (liberal), secondary clean -> hc1; other forms unaffected
  r2 <- ipw_summarize(mk(function(cl, fm, arm) if (arm == "stacked_hc3" && fm == "sj" && cl$dgm == "auxj" && cl$n == 200 && cl$miss == .40 && cl$point == "P1") list(rej = .10)))
  stopifnot(dec(r2, "sj") == "viable: hc1", dec(r2, "uj") == "viable: hc3", dec(r2, "spv") == "viable: hc3")
  # (3) both variants fail -> none, only for that form
  r3 <- ipw_summarize(mk(function(cl, fm, arm) if (arm %in% VARIANTS && fm == "sjt" && cl$dgm == "stdj" && cl$n == 500 && cl$miss == .25 && cl$point == "P4") list(cov = .90, rej = .5)))
  stopifnot(dec(r3, "sjt") == "none", dec(r3, "sj") == "viable: hc3")
  # (4) a failure in a NON-decisive cell (uj on auxm, independent missingness) does not decide
  r4 <- ipw_summarize(mk(function(cl, fm, arm) if (grepl("^stacked", arm) && fm == "uj" && cl$dgm == "auxm" && cl$point == "P1") list(rej = .20)))
  stopifnot(dec(r4, "uj") == "viable: hc3")
  # (5) bias-limited cell: shipped path fails coverage (.90), stacked within .01 -> still viable and labelled;
  #     stacked .87 -> not viable
  lim <- function(sc) function(cl, fm, arm) if (cl$dgm == "auxm" && fm == "spv" && cl$n == 500 && cl$miss == .40 && cl$point == "P4") {
    if (arm == "known_hc3") list(cov = .90) else if (arm %in% VARIANTS) list(cov = sc) }
  r5 <- ipw_summarize(mk(lim(.895)))
  stopifnot(dec(r5, "spv") == "viable: hc3", !is.null(r5$bias_limited), any(r5$bias_limited$form == "spv"))
  r5b <- ipw_summarize(mk(lim(.87)))
  stopifnot(dec(r5b, "spv") == "none")
  # (6) an all-dropped decisive cell fails the criteria and is flagged, no crash
  r6 <- ipw_summarize(mk(drop = function(cl, fm, arm) arm == "stacked_hc3" && fm == "uj" && cl$dgm == "stdj" && cl$n == 200 && cl$miss == .25 && cl$point == "P1"))
  stopifnot(!r6$crit$viable[r6$crit$form == "uj" & r6$crit$variant == "stacked_hc3"], dec(r6, "uj") == "viable: hc1")
  # (7) a blind control arm fails control 2
  r7 <- ipw_summarize(mk(function(cl, fm, arm) if (arm == "model_se") list(rej = .05)))
  stopifnot(!r7$control2)
  cat("selftest OK: clean -> hc3 viable; one failing cell -> hc1; both fail -> none (that form only); non-decisive failure ignored; bias-limited cell labelled (and 0.87 fails); all-dropped cell fails without crashing; blind control arm -> control 2 FAIL\n")
}

args <- commandArgs(TRUE)
if ("--selftest" %in% args) { selftest(); quit(save = "no") }
if (length(args) >= 1L && args[1] != "--selftest") {
  fs <- list.files(args[1], "^task_.*\\.rds$", full.names = TRUE)
  stopifnot(length(fs) > 0)
  tk <- lapply(fs, readRDS)
  res <- do.call(rbind, lapply(tk, function(x) cbind(x$cl[rep(1, nrow(x$res)), c("dgm", "n", "miss", "point")], x$res)))
  cat(sprintf("%d task files, %d rows, missingmed %s, %.0f total task-seconds\n", length(fs), nrow(res),
    paste(unique(vapply(tk, `[[`, "", "version")), collapse = "/"), sum(vapply(tk, `[[`, 0, "secs"))))
  cell_reps <- tapply(res$rep[res$arm == "known_hc3" & res$form == "uj"], paste(res$dgm, res$n, res$miss, res$point)[res$arm == "known_hc3" & res$form == "uj"], length)
  complete <- length(cell_reps) == 96 && all(cell_reps >= 2000)
  if (!complete) cat(sprintf("INCOMPLETE RUN: %d of 96 cells, %d to %d replications per cell (full run: 96 cells x 2000). Decisions below are NOT valid.\n\n",
    length(cell_reps), min(cell_reps), max(cell_reps)))
  ipw_report(ipw_summarize(res))
}
