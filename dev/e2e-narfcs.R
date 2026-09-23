# End-to-end gate for NARFCS delegation in sensitivity_mnar().
#
# Run from the package root:
#   Rscript dev/e2e-narfcs.R
#
# Two kinds of case, both able to fail (docs/specs/GRILL-narfcs-delegation-2026-09-23.md, P4):
# * NEGATIVE CONTROLS -- inputs that once produced a silent wrong result. Each
#   must now ERROR, with a message naming the cause. "RAN" is RED.
# * KNOWN ANSWERS -- one per route. delta = 0 (or ums = "0") must reproduce the
#   MAR analysis's D4 exactly, via the expected @mechanism_used.
# Exits non-zero if any case is RED.

suppressMessages(devtools::load_all(".", quiet = TRUE))

gen <- function(n = 400, seed = 4, binary = FALSE) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- if (binary) rbinom(n, 1, plogis(-0.3 + 0.8 * X + 0.3 * C)) else 0.6 * X + 0.3 * C + rnorm(n)
  Y <- 0.2 * X + 0.5 * M + 0.3 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  d$M[runif(n) < 0.3] <- NA
  d
}
md_of <- function(d, method = NULL, family_m = stats::gaussian(), med = "M") {
  meth <- mice::make.method(d)
  if (!is.null(method)) meth[med] <- method
  imp <- suppressWarnings(mice::mice(d, m = 3, maxit = 3, method = meth, seed = 1, printFlag = FALSE))
  set_md_mediation(imp, stats::as.formula(paste("Y ~ X +", med, "+ C")),
    stats::as.formula(paste(med, "~ X + C")),
    treatment = "X", mediator = med, family_m = family_m
  )
}

results <- list()
record <- function(name, ok, detail) {
  results[[name]] <<- ok
  cat(sprintf("[%s] %-38s %s\n", if (ok) "PASS" else "RED ", name, detail))
}
negative <- function(name, expr, cause) {
  out <- tryCatch({
    suppressWarnings(suppressMessages(force(expr)))
    NULL
  }, error = function(e) conditionMessage(e))
  if (is.null(out)) {
    record(name, FALSE, "RAN -- the silent wrong result is still reachable")
  } else {
    record(name, grepl(cause, out, ignore.case = TRUE),
      paste0("ERROR: ", substr(gsub("\\s+", " ", out), 1, 90)))
  }
}
known <- function(name, md, mech, ...) {
  sens <- suppressWarnings(suppressMessages(sensitivity_mnar(md, type = "mbco", ...)))
  base <- suppressWarnings(infer(run(md), type = "mbco"))
  same <- isTRUE(all.equal(unname(sens@rungs[[1]][["D4"]]), unname(base[["D4"]])))
  record(name, same && identical(sens@mechanism_used, mech),
    sprintf("mechanism = %s (want %s), D4 = %.6g vs MAR %.6g",
      sens@mechanism_used, mech, sens@rungs[[1]][["D4"]], base[["D4"]]))
}

cat("== Negative controls (each must error, naming the cause) ==\n")
md_norm <- md_of(gen(), method = "norm")
negative("R1 ums NA-coefficient", sensitivity_mnar(md_norm, ums = c("0", "0.5 + garbageZZ*C"), type = "mbco"), "ums")
negative("R3 NA delta", sensitivity_mnar(md_norm, delta = c(0, NA), type = "mbco"), "delta")
d_msp <- gen(); names(d_msp)[names(d_msp) == "M"] <- "msp"
negative("R2 target named msp", sensitivity_mnar(md_of(d_msp, method = "norm", med = "msp"), delta = c(0, 2), type = "mbco"), "msp")
negative("D1 pmm 0/1 target (gaussian)", sensitivity_mnar(md_of(gen(binary = TRUE)), delta = 1, type = "mbco"), "logreg")

cat("\n== Known answers (delta = 0 reproduces MAR on each route) ==\n")
known("post route (pmm, continuous)", md_of(gen()), "post", delta = 0)
known("mnar.norm route (ums = \"0\")", md_norm, "mnar.norm", ums = "0")
known("mnar.logreg route (binary logreg)", md_of(gen(binary = TRUE), method = "logreg", family_m = stats::binomial()), "mnar.logreg", delta = 0)

n_red <- sum(!unlist(results))
cat(sprintf("\n%d/%d PASS, %d RED\n", length(results) - n_red, length(results), n_red))
quit(status = if (n_red) 1L else 0L)
