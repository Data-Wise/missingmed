# Criteria C1-C5, controls and the per-weight-form decision for the IPW stack
# coverage gate (SPEC-ipw-stack-coverage-2026-10-09.md, section 3 and Addendum A).
#   Rscript dev/sim-ipw-stack-combine.R <task-dir>     summarize a run
#   Rscript dev/sim-ipw-stack-combine.R --selftest     planted-result test of the logic
# Not part of the package build.
SIZE_BAR <- .065; COV_BAR <- .935; DRIFT <- .010; DROP_BAR <- .01

# `res`: one row per (cell, rep, form, arm), with the cell columns dgm, n, miss, point
# and the columns of one_ipw(). Returns the per-cell table, criteria and decisions.
ipw_summarize <- function(res) {
  res$cellkey <- paste(res$dgm, res$n, res$miss, res$point)
  res$ok <- is.na(res$error) & !is.na(res$lo)
  nullpt <- res$point %in% c("P1", "P2", "P3")
  g <- function(x) paste(x$cellkey, x$form, x$arm)
  rows <- lapply(split(res, g(res)), function(x) {
    data.frame(dgm = x$dgm[1], n = x$n[1], miss = x$miss[1], point = x$point[1], form = x$form[1],
      arm = x$arm[1], reps = nrow(x), dropped = mean(!x$ok),
      reject = mean(x$reject0[x$ok]), cover = mean(x$cover[x$ok]),
      width = stats::median(x$width[x$ok]), stringsAsFactors = FALSE)
  })
  tab <- do.call(rbind, rows); rownames(tab) <- NULL
  tab$is_null <- tab$point %in% c("P1", "P2", "P3")
  tab$conditional <- tab$dropped > DROP_BAR
  # paired comparison stacked vs known_hc3 (same replications)
  pr <- lapply(split(res[res$arm %in% c("stacked", "known_hc3"), ],
    paste(res$cellkey, res$form)[res$arm %in% c("stacked", "known_hc3")]), function(x) {
    s <- x[x$arm == "stacked", ]; k <- x[x$arm == "known_hc3", ]
    m <- merge(s[, c("rep", "reject0", "width", "ok")], k[, c("rep", "reject0", "width", "ok")], by = "rep", suffixes = c("_s", "_k"))
    m <- m[m$ok_s & m$ok_k, ]
    n01 <- sum(m$reject0_s & !m$reject0_k); n10 <- sum(!m$reject0_s & m$reject0_k)
    data.frame(dgm = x$dgm[1], n = x$n[1], miss = x$miss[1], point = x$point[1], form = x$form[1],
      n_stacked_only = n01, n_known_only = n10,
      mcnemar_p = if (n01 + n10 > 0) stats::binom.test(n01, n01 + n10, .5)$p.value else 1,
      width_ratio = stats::median(m$width_s / m$width_k), stringsAsFactors = FALSE)
  })
  pair <- do.call(rbind, pr); rownames(pair) <- NULL
  # criteria per weight form, over all dgm x n x miss x point cells
  crit <- do.call(rbind, lapply(sort(unique(tab$form)), function(fm) {
    st <- tab[tab$form == fm & tab$arm == "stacked", ]
    kn <- tab[tab$form == fm & tab$arm == "known_hc3", ]
    mm <- merge(st, kn, by = c("dgm", "n", "miss", "point"), suffixes = c("_s", "_k"))
    # a NaN (every replication of an arm dropped) must FAIL a criterion, not crash it
    c1 <- isTRUE(all(mm$reject_s[mm$is_null_s] <= SIZE_BAR) && all(mm$cover_s[!mm$is_null_s] >= COV_BAR))
    c1_known <- isTRUE(all(mm$reject_k[mm$is_null_s] <= SIZE_BAR) && all(mm$cover_k[!mm$is_null_s] >= COV_BAR))
    c2 <- isTRUE(all(mm$reject_s[mm$is_null_s] - mm$reject_k[mm$is_null_s] <= DRIFT) &&
      all(mm$cover_s[!mm$is_null_s] - mm$cover_k[!mm$is_null_s] >= -DRIFT))
    c3 <- isTRUE(all(mm$reject_s[!mm$is_null_s] - mm$reject_k[!mm$is_null_s] >= -DRIFT))
    pf <- pair[pair$form == fm, ]
    mm2 <- merge(pf, mm[, c("dgm", "n", "miss", "point", "reject_s", "reject_k", "width_s", "width_k", "is_null_s")],
      by = c("dgm", "n", "miss", "point"))
    closer <- abs(mm2$reject_s - .05) < abs(mm2$reject_k - .05) | mm2$width_ratio < 1
    benefit <- any(mm2$mcnemar_p < .01 & closer & mm2$is_null_s) ||
      any(mm2$mcnemar_p < .01 & mm2$width_ratio < 1)
    cond <- any(tab$conditional[tab$form == fm & tab$arm %in% c("stacked", "known_hc3")])
    decision <- if (c1 && c2 && c3) {
      if (benefit) "STACKED DEFAULT (benefit shown)" else "STACKED DEFAULT (correctness alone; intervals may move either way)"
    } else if (!c2 || !c3) "STACKED OPT-IN (worse than today in some cell)"
    else if (c1_known) {
      if (fm == "sjt") "REFUSE stacking with weight_trim < 1; keep known-weights" else "STACKED OPT-IN (C1 fails, known passes)"
    } else "NEITHER VALIDATED (document the cell; no default change)"
    data.frame(form = fm, C1 = c1, C1_known_hc3 = c1_known, C2 = c2, C3 = c3, benefit = benefit,
      conditional_cells = cond, decision = decision, stringsAsFactors = FALSE)
  }))
  # control 2: the model-based arm must show a detectable size distortion in an aux/auxm cell
  ms <- tab[tab$arm == "model_se" & tab$dgm %in% c("aux", "auxm") & tab$is_null, ]
  control2 <- nrow(ms) > 0 && any(ms$reject > SIZE_BAR | ms$reject < .035)
  list(tab = tab, pair = pair, crit = crit, control2 = control2,
    borderline = tab[tab$arm == "stacked" & tab$is_null & tab$reject > SIZE_BAR & tab$reject <= .070, ])
}

ipw_report <- function(r) {
  cat(sprintf("CONTROL 2 (model-based arm shows a detectable size distortion in aux/auxm): %s\n",
    if (r$control2) "PASS" else "FAIL - the grid cannot see a wrong variance; results below do not count"))
  cat("\nCRITERIA AND DECISION PER WEIGHT FORM\n"); print(r$crit, row.names = FALSE)
  cat("\nFAILURE SHARES (C5): arms with more than 1% dropped replications (sizes there are conditional)\n")
  d <- r$tab[r$tab$conditional, c("dgm", "n", "miss", "point", "form", "arm", "dropped")]
  if (nrow(d)) print(d, row.names = FALSE) else cat("none\n")
  cat("\nBORDERLINE (stacked size in (0.065, 0.070]): rerun these cells with 10000 replications\n")
  if (nrow(r$borderline)) print(r$borderline[, c("dgm", "n", "miss", "point", "form", "reject")], row.names = FALSE) else cat("none\n")
  cat("\nPAIRED stacked vs known_hc3 (cells with McNemar p < 0.01)\n")
  p <- r$pair[r$pair$mcnemar_p < .01, ]
  if (nrow(p)) print(p, row.names = FALSE, digits = 3) else cat("none\n")
  cat("\nSIZE / COVERAGE TABLE (stacked, known_hc3, known_hc0, model_se)\n"); print(r$tab[, c("dgm", "n", "miss", "point", "form", "arm", "reject", "cover", "width", "dropped")], row.names = FALSE, digits = 3)
}

selftest <- function() {
  set.seed(1)
  cells <- expand.grid(dgm = c("std", "aux", "auxm"), n = c(200, 500), miss = c(.25, .40),
    point = c("P1", "P2", "P3", "P4"), stringsAsFactors = FALSE)
  mk <- function(liberal = FALSE, drop = FALSE, modelok = TRUE) {
    out <- list(); R <- 2000
    for (i in seq_len(nrow(cells))) for (fm in c("uj", "sj", "sjt", "spv")) {
      cl <- cells[i, ]; nul <- cl$point != "P4"
      u <- stats::runif(R); u2 <- stats::runif(R)  # shared across arms: paired
      for (arm in c("known_hc3", "known_hc0", "stacked", if (fm == "uj") "model_se")) {
        p <- if (nul) .045 else .60
        if (arm == "stacked" && liberal && fm == "sj" && cl$dgm == "aux" && cl$n == 200 && cl$miss == .40 && cl$point == "P1") p <- .09
        if (arm == "model_se" && modelok && cl$dgm == "aux" && nul) p <- .12
        rej <- u < p
        err <- rep(NA_character_, R)
        if (drop && arm == "stacked" && fm == "spv" && i == 1) err[1:80] <- "stacked variance failed"
        out[[length(out) + 1L]] <- data.frame(cl, form = fm, arm = arm, rep = seq_len(R), error = err, row.names = NULL,
          lo = ifelse(rej, .1, -.1), hi = ifelse(rej, .3, .1), reject0 = rej,
          cover = if (nul) !rej else u2 > .05, width = .2, stringsAsFactors = FALSE)
      }
    }
    do.call(rbind, out)
  }
  clean <- ipw_summarize(mk())
  stopifnot(all(clean$crit$C1), all(clean$crit$C2), all(clean$crit$C3), clean$control2,
    all(grepl("^STACKED DEFAULT", clean$crit$decision)))
  lib <- ipw_summarize(mk(liberal = TRUE))
  stopifnot(!lib$crit$C1[lib$crit$form == "sj"], !lib$crit$C2[lib$crit$form == "sj"],
    grepl("OPT-IN", lib$crit$decision[lib$crit$form == "sj"]),
    all(lib$crit$C1[lib$crit$form != "sj"]))
  dr <- ipw_summarize(mk(drop = TRUE))
  stopifnot(dr$crit$conditional_cells[dr$crit$form == "spv"], !dr$crit$conditional_cells[dr$crit$form == "uj"])
  nm <- ipw_summarize(mk(modelok = FALSE))
  stopifnot(!nm$control2)
  # a cell where every replication of the stacked arm failed must fail the criteria, not crash
  allfail <- mk(); i <- allfail$arm == "stacked" & allfail$form == "uj" & allfail$dgm == "std" & allfail$n == 200 & allfail$miss == .25 & allfail$point == "P1"
  allfail$error[i] <- "stacked variance failed"
  af <- ipw_summarize(allfail)
  stopifnot(!af$crit$C1[af$crit$form == "uj"], af$crit$conditional_cells[af$crit$form == "uj"])
  cat("selftest OK: clean data -> STACKED DEFAULT; one liberal cell -> that form only fails C1/C2 and goes opt-in; 4% dropped column flagged conditional; blind control arm -> control 2 FAIL\n")
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
  per_cell <- table(paste(res$dgm, res$n, res$miss, res$point), res$form, res$arm)[, 1, 1]
  complete <- length(per_cell) == 48 && all(per_cell >= 2000)
  if (!complete) cat(sprintf("INCOMPLETE RUN: %d of 48 cells, %d to %d replications per cell (full run: 48 cells x 2000). Decisions below are NOT valid.\n\n",
    length(per_cell), min(per_cell), max(per_cell)))
  ipw_report(ipw_summarize(res))
}
