# Criteria C1-C5, controls and the decision for the missingness-model gate
# (SPEC-ipw-missingness-default-2026-10-09.md sections 5 and 8a). Applied as written.
#   Rscript dev/sim-ipw-mech-combine.R <task-dir>     summarize a run
#   Rscript dev/sim-ipw-mech-combine.R --selftest     planted-outcome test of the logic
# Not part of the package build.
BIAS_BAR <- .010; COV_BAR <- .93; SIZE_BAR <- .065; DRIFT <- .010; RMSE_RATIO <- 1.05
FAIL_BAR <- .01; PLANT_BAR <- .03
KEY <- c("mech", "dgm", "n", "miss", "point")

# `res`: one row per (cell, rep, form): the cell columns mech, dgm, n, miss, point plus
# the columns of one_mech(). Returns the per-(cell, form) table.
mech_summarize <- function(res) {
  res$fail <- !is.na(res$error) | (!is.na(res$nonconv) & res$nonconv > 0) | is.na(res$lo) | (!is.na(res$pd) & res$pd == 0)
  res$ok <- !res$fail
  rows <- lapply(split(res, do.call(paste, c(res[KEY], res["form"]))), function(x) {
    xo <- x[x$ok, ]
    data.frame(x[1, KEY], form = x$form[1], reps = nrow(x), failed = mean(x$fail),
      degenerate = mean(x$degenerate > 0, na.rm = TRUE),
      fallback = if ("fallback" %in% names(x)) mean(x$fallback > 0, na.rm = TRUE) else NA_real_,
      bias_b = mean(x$b - x$truth_b, na.rm = TRUE), bias_a = mean(x$a - x$truth_a, na.rm = TRUE),
      rmse_b = sqrt(mean((x$b - x$truth_b)^2, na.rm = TRUE)),
      cover = mean(xo$cover), reject = mean(xo$reject0), width = stats::median(xo$width),
      stringsAsFactors = FALSE)
  })
  tab <- do.call(rbind, rows); rownames(tab) <- NULL
  tab$is_null <- tab$point != "P4"
  tab
}

# Criteria for the sequential form, controls, decision.
mech_decide <- function(tab, res = NULL) {
  at <- function(form) { x <- tab[tab$form == form, ]; x[do.call(order, x[KEY]), ] }
  sq <- at("seq"); jt <- at("joint"); mg <- at("marginal"); tr <- at("true"); rv <- at("seqrev")
  big <- function(x) x[x$n == 5000, ]
  # controls (spec 8a items 1 and 2)
  pl <- mg[mg$mech == "sim" & mg$dgm == "auxm" & mg$point == "P4" & mg$miss == .40 & mg$n == 5000, ]
  c_plant <- nrow(pl) == 1L && isTRUE(abs(pl$bias_b) > PLANT_BAR)
  trb <- big(tr)
  c_true <- nrow(trb) > 0 && all(abs(trb$bias_b) <= BIAS_BAR, na.rm = FALSE) && !anyNA(trb$bias_b)
  controls_ok <- c_plant && c_true
  # C1: consistency of sequential at n = 5000, every cell
  s5 <- big(sq)
  c1 <- nrow(s5) > 0 && !anyNA(s5$bias_b) && all(abs(s5$bias_b) <= BIAS_BAR)
  c1_bad <- s5[is.na(s5$bias_b) | abs(s5$bias_b) > BIAS_BAR, c(KEY, "bias_b")]
  # C2: coverage / size at n = 5000, with the escape clause against the known-weights arm
  m2 <- merge(s5, big(tr)[, c(KEY, "cover", "reject")], by = KEY, suffixes = c("", "_true"))
  pass2 <- ifelse(m2$is_null,
    (m2$reject <= SIZE_BAR | m2$reject - m2$reject_true <= DRIFT),
    (m2$cover >= COV_BAR | m2$cover - m2$cover_true >= -DRIFT))
  pass2 <- pass2 %in% TRUE
  c2 <- nrow(m2) > 0 && all(pass2)
  c2_bad <- m2[!pass2, c(KEY, "cover", "cover_true", "reject", "reject_true")]
  # C3: non-inferiority to the joint default in the simultaneous mechanism, n = 200, 500
  s3 <- sq[sq$mech == "sim" & sq$n %in% c(200, 500), ]
  m3 <- merge(s3, jt[, c(KEY, "cover", "reject", "rmse_b")], by = KEY, suffixes = c("", "_joint"))
  pass3 <- ifelse(m3$is_null, m3$reject - m3$reject_joint <= DRIFT, m3$cover - m3$cover_joint >= -DRIFT) %in% TRUE &
    (m3$rmse_b <= RMSE_RATIO * m3$rmse_b_joint) %in% TRUE
  c3 <- nrow(m3) > 0 && all(pass3)
  c3_bad <- m3[!pass3, c(KEY, "cover", "cover_joint", "reject", "reject_joint", "rmse_b", "rmse_b_joint")]
  # C4: failures
  c4 <- nrow(sq) > 0 && all(sq$failed <= FAIL_BAR)
  c4_bad <- sq[sq$failed > FAIL_BAR, c(KEY, "failed")]
  # C5 (reported): the cost of the wrong order under monotone missingness
  c5 <- big(rv)[big(rv)$mech == "mono", c(KEY, "bias_b")]
  decision <- if (!controls_ok) "VOID: a control failed; the run decides nothing"
    else if (!c1) "NO CHANGE: C1 fails; the sequential form is not consistent in every n = 5000 cell"
    else if (c2 && c3 && c4) "ADOPT D: the sequential form becomes the default (spec section 6)"
    else "KEEP JOINT DEFAULT: add the warning (B) and ship the sequential form as an opt-in"
  list(controls = c(planted_defect = c_plant, known_weights = c_true), C1 = c1, C2 = c2, C3 = c3, C4 = c4,
    c1_bad = c1_bad, c2_bad = c2_bad, c3_bad = c3_bad, c4_bad = c4_bad, c5 = c5, decision = decision)
}

mech_report <- function(res) {
  tab <- mech_summarize(res)
  d <- mech_decide(tab, res)
  cat("=== Per-form mean bias in b at n = 5000 (rows: mechanism x DGM, miss 0.40, P4) ===\n")
  w <- tab[tab$n == 5000 & tab$miss == .40 & tab$point == "P4", c("mech", "dgm", "form", "bias_b")]
  print(reshape(w, idvar = c("mech", "dgm"), timevar = "form", direction = "wide"), digits = 3, row.names = FALSE)
  cat("\n=== Controls ===\n"); print(d$controls)
  for (k in c("C1", "C2", "C3", "C4")) cat(sprintf("%s: %s\n", k, if (isTRUE(d[[k]])) "PASS" else "FAIL"))
  for (k in c("c1_bad", "c2_bad", "c3_bad", "c4_bad")) if (nrow(d[[k]])) { cat("\nFailing cells,", k, ":\n"); print(d[[k]], digits = 3, row.names = FALSE) }
  cat("\nC5 (reported): reversed order, monotone, n = 5000, bias in b\n"); print(d$c5, digits = 3, row.names = FALSE)
  cat("\nDECISION:", d$decision, "\n")
  invisible(list(tab = tab, decision = d))
}

selftest <- function() {
  set.seed(1)
  cells <- expand.grid(mech = c("ind", "sim", "mono"), dgm = c("std", "aux", "auxm"), n = c(200, 500, 5000),
    miss = c(.25, .40), point = c("P1", "P2", "P4"), stringsAsFactors = FALSE)
  # `spec(mech, dgm, n, miss, point, form)` -> list(bias, cover_p, reject_p, fail_p)
  gen <- function(spec, reps = 100) {
    out <- list()
    for (i in seq_len(nrow(cells))) {
      noise <- rnorm(reps, 0, .001)   # shared by the forms of a cell, as paired replications are
      for (f in c("joint", "marginal", "seq", "seqrev", "true")) {
      cl <- cells[i, ]; s <- spec(cl, f)
      rep <- seq_len(reps)
      cov <- rep <= round(reps * s$cover); rej <- rep <= round(reps * s$reject)
      fail <- rep <= round(reps * s$fail)
      out[[length(out) + 1L]] <- data.frame(cl, form = f, rep = rep,
        a = .3, b = .3 + s$bias + noise, truth_a = .3, truth_b = .3, lo = ifelse(cov, 0, 1), hi = ifelse(cov, 1, 2),
        pd = 1, cover = cov, reject0 = rej, width = 1, degenerate = 0L, nonconv = 0L,
        error = ifelse(fail, "boom", NA_character_), stringsAsFactors = FALSE, row.names = NULL)
      }
    }
    do.call(rbind, out)
  }
  good <- function(cl, f) list(bias = if (f == "marginal" && cl$mech == "sim" && cl$dgm == "auxm") .05 else 0,
    cover = .95, reject = if (cl$point == "P4") .95 else .05, fail = 0)
  run <- function(spec) mech_decide(mech_summarize(gen(spec)))
  ok <- TRUE
  chk <- function(label, cond) { cat(sprintf("%-4s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", label)); ok <<- ok && isTRUE(cond) }
  d <- run(good); chk("clean run -> ADOPT D", grepl("^ADOPT D", d$decision))
  d <- run(function(cl, f) { s <- good(cl, f); if (f == "seq" && cl$n == 5000 && cl$mech == "ind" && cl$dgm == "auxm") s$bias <- .02; s })
  chk("one sequential cell with bias .02 at n = 5000 -> NO CHANGE (C1)", grepl("^NO CHANGE", d$decision) && !d$C1)
  d <- run(function(cl, f) { s <- good(cl, f); if (f == "seq" && cl$mech == "sim" && cl$n == 200 && cl$point == "P4") s$cover <- .90; s })
  chk("sequential coverage .90 vs joint .95 at one sim cell -> KEEP JOINT (C3)", grepl("^KEEP JOINT", d$decision) && !d$C3)
  d <- run(function(cl, f) { s <- good(cl, f); if (f == "seq" && cl$n == 5000 && cl$mech == "mono" && cl$point == "P4") s$cover <- .90; s })
  chk("sequential coverage .90 at n = 5000 while the true-weights arm is .95 -> KEEP JOINT (C2)", grepl("^KEEP JOINT", d$decision) && !d$C2)
  d <- run(function(cl, f) { s <- good(cl, f); if (cl$n == 5000 && cl$mech == "mono" && cl$point == "P4") s$cover <- .90; s })
  chk("coverage .90 for every arm at n = 5000 (the variance's own limit, true arm too) -> C2 passes by the escape clause",
    d$C2 && grepl("^ADOPT D", d$decision))
  d <- run(function(cl, f) { s <- good(cl, f); if (f == "seq" && cl$mech == "ind" && cl$n == 500) s$fail <- .05; s })
  chk("5% of sequential replications failing -> KEEP JOINT (C4)", grepl("^KEEP JOINT", d$decision) && !d$C4)
  d <- run(function(cl, f) { s <- good(cl, f); if (f == "marginal") s$bias <- 0; s })
  chk("a planted defect the grid cannot see (marginal unbiased under sim) -> VOID", grepl("^VOID", d$decision) && !d$controls[["planted_defect"]])
  d <- run(function(cl, f) { s <- good(cl, f); if (f == "true" && cl$n == 5000 && cl$mech == "ind") s$bias <- .02; s })
  chk("known-weights arm biased -> VOID", grepl("^VOID", d$decision) && !d$controls[["known_weights"]])
  d <- run(function(cl, f) { s <- good(cl, f); if (f == "seq" && cl$n == 500) { s$fail <- 1 }; s })
  chk("an all-failed sequential cell does not crash and fails C4", !d$C4)
  cat(if (ok) "\nselftest OK\n" else "\nselftest FAILED\n"); quit(status = if (ok) 0L else 1L)
}

args <- commandArgs(TRUE)
if ("--selftest" %in% args) {
  selftest()
} else if (length(args) == 1L) {
  files <- list.files(args[1], pattern = "^task_.*\\.rds$", full.names = TRUE)
  stopifnot(length(files) > 0)
  parts <- lapply(files, function(f) { x <- readRDS(f); cbind(x$cl[rep(1, nrow(x$res)), c("mech", "dgm", "n", "miss", "point")], x$res) })
  res <- do.call(rbind, parts)
  expected <- 162
  got <- length(unique(do.call(paste, res[c("mech", "dgm", "n", "miss", "point")])))
  if (got != expected) {
    cat(sprintf("INCOMPLETE RUN: %d of %d cells present; no decision is valid\n", got, expected))
    quit(status = 2L)
  }
  mech_report(res)
}
