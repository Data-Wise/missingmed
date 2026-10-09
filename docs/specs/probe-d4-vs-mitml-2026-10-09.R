suppressMessages({devtools::load_all(".", quiet = TRUE); library(mitml)})
set.seed(21); n <- 300
C <- rnorm(n); X <- rbinom(n, 1, .5); M <- .5 * X + .3 * C + rnorm(n)
Y <- .25 * M + .2 * X + .3 * C + rnorm(n)
d <- data.frame(X, M, Y, C); d$M[runif(n) < plogis(-.7 + .5 * C + .5 * Y)] <- NA
K <- 20
imp <- suppressWarnings(mice::mice(d, m = K, maxit = 5, method = "norm", printFlag = FALSE, seed = 3))
il <- mice::complete(imp, "all")
ml <- as.mitml.list(il)

# ---- (1) the pooling arithmetic, k = 1 and k = 2: .mm_d4_from_stats vs mitml D4
cmp <- function(f1, f0, label) {
  ll <- function(f, dd) as.numeric(logLik(glm(f, data = dd)))
  d_k <- vapply(il, function(dd) 2 * (ll(f1, dd) - ll(f0, dd)), 0)
  st <- do.call(rbind, il)
  d_S <- 2 * (ll(f1, st) - ll(f0, st)) / K
  k <- length(attr(terms(f1), "term.labels")) - length(attr(terms(f0), "term.labels"))
  mine <- missingmed:::.mm_d4_from_stats(d_k, d_S, k = k)
  fit1 <- structure(lapply(il, function(dd) do.call(glm, list(formula = f1, data = dd))), class = "mitml.result"); fit0 <- structure(lapply(il, function(dd) do.call(glm, list(formula = f0, data = dd))), class = "mitml.result")
  mt <- suppressWarnings(testModels(fit1, fit0, method = "D4", data = il))$test
  cat(sprintf("\n[%s] k = %d\n", label, k))
  print(data.frame(
    quantity = c("D4 (F)", "df1", "df2 / nu", "p", "r4 / RIV"),
    missingmed = c(mine[["D4"]], k, mine[["nu"]], mine[["p"]], mine[["r4"]]),
    mitml = c(mt[1, "F.value"], mt[1, "df1"], mt[1, "df2"], mt[1, "P(>F)"], mt[1, "RIV"])), digits = 10)
  invisible(NULL)
}
cmp(Y ~ M + X + C, Y ~ X + C, "outcome: drop M")
cmp(Y ~ M + X + C, Y ~ C, "outcome: drop M and X")

# ---- (2) end to end: mbco_d4() with ariv = "fixed" vs mitml D4 on the stacked branch
r <- mbco_d4(il, Y ~ M + X + C, M ~ X + C, treatment = "X", mediator = "M", ariv = "fixed")
cat("\n[mbco_d4, fixed] stacked branch:", r@stacked_branch, "\n"); print(round(unclass(S7::S7_data(r)), 8))
f0 <- if (r@stacked_branch == "b") Y ~ X + C else NULL
if (!is.null(f0)) {
  fit1 <- structure(lapply(il, function(dd) do.call(glm, list(formula = Y ~ M + X + C, data = dd))), class = "mitml.result"); fit0 <- structure(lapply(il, function(dd) do.call(glm, list(formula = f0, data = dd))), class = "mitml.result")
  mt <- suppressWarnings(testModels(fit1, fit0, method = "D4", data = il))$test
  cat("mitml D4 on the b = 0 outcome model: F =", mt[1, "F.value"], " df2 =", mt[1, "df2"], " RIV =", mt[1, "RIV"], " p =", mt[1, "P(>F)"], "\n")
}
