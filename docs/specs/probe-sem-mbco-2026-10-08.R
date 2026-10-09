# Spec-by-example for SPEC-sem-mbco-2026-10-08.md: the lavaan log-likelihood
# triple (full, a = 0, b = 0) that the D4-MBCO engine needs, built from the
# FITTED full model's parameter table. Run: Rscript docs/specs/probe-sem-mbco-2026-10-08.R
# Needs lavaan >= 0.7-3. Reads nothing from the package; prints PASS/FAIL lines.
suppressMessages(library(lavaan))
failed <- character()
ok <- function(label, cond) {
  cat(if (isTRUE(cond)) "PASS " else "FAIL ", label, "\n")
  if (!isTRUE(cond)) failed <<- c(failed, label)
}
quiet <- function(expr) suppressWarnings(expr)
ll <- function(f) as.numeric(logLik(f))

# The constrained model: the fitted full model's table with ONE structural
# regression fixed to 0. Starting from parTable(fit) (not lavaanify()) keeps
# every default sem() applied, so latent models stay identified.
constrain <- function(fit, lhs, rhs, data) {
  pt <- parTable(fit)
  i <- which(pt$lhs == lhs & pt$op == "~" & pt$rhs == rhs)
  stopifnot(length(i) == 1L)
  pt$free[i] <- 0L
  pt$ustart[i] <- 0
  pt[c("est", "se", "start")] <- NULL
  pt$free[pt$free > 0] <- seq_len(sum(pt$free > 0))
  quiet(lavaan(pt, data = data))
}
triple <- function(model, data, a, b, ...) {
  full <- quiet(sem(model, data = data, ...))
  stopifnot(lavInspect(full, "converged"))
  A <- constrain(full, a[1], a[2], data)
  B <- constrain(full, b[1], b[2], data)
  c(full = ll(full), a = ll(A), b = ll(B),
    k_a = lavInspect(full, "npar") - lavInspect(A, "npar"),
    k_b = lavInspect(full, "npar") - lavInspect(B, "npar"))
}
T_union <- function(t) 2 * (t[["full"]] - max(t[["a"]], t[["b"]]))

# ---- 1. observed path model: parity with the glm triple D4-MBCO uses today ----
set.seed(7); n <- 300
C <- rnorm(n); X <- rnorm(n)
M <- .35 * X + .3 * C + rnorm(n)
Y <- .30 * M + .2 * X + .3 * C + rnorm(n)
d <- data.frame(X, M, Y, C)
obs <- "M ~ X + C\nY ~ M + X + C"
t_lav <- triple(obs, d, c("M", "X"), c("Y", "M"), meanstructure = TRUE)
g <- function(f) as.numeric(logLik(glm(f, data = d)))
t_glm <- c(full = g(M ~ X + C) + g(Y ~ M + X + C),
           a = g(M ~ C) + g(Y ~ M + X + C),
           b = g(M ~ X + C) + g(Y ~ X + C))
ok("observed: triple equals the glm triple (1e-9)", max(abs(t_lav[1:3] - t_glm)) < 1e-9)
ok("observed: k = 1 on both branches", all(t_lav[c("k_a", "k_b")] == 1))
ok("observed: branch-union T equals the glm T (1e-9)",
   abs(T_union(t_lav) - T_union(t_glm)) < 1e-9)
f1 <- quiet(sem(obs, data = d, meanstructure = TRUE))
f0 <- quiet(sem("M ~ 0*X + C\nY ~ M + X + C", data = d, meanstructure = TRUE))
ok("observed: a = 0 LRT equals lavTestLRT() (1e-8)",
   abs(2 * (t_lav[["full"]] - t_lav[["a"]]) - lavTestLRT(f1, f0)[2, "Chisq diff"]) < 1e-8)

# ---- 2. stacked copies: T_stacked / K equals the single-dataset T ------------
K <- 4
st <- do.call(rbind, rep(list(d), K))
t_st <- triple(obs, st, c("M", "X"), c("Y", "M"), meanstructure = TRUE)
ok("stacked: T / K equals the single-dataset T (1e-9)",
   abs(T_union(t_st) / K - T_union(t_lav)) < 1e-9)

# ---- 3. latent mediator: constrained fits equal sem() with 0* syntax ---------
set.seed(8); n <- 400
X <- rnorm(n); Ml <- .5 * X + rnorm(n); Y <- .4 * Ml + .2 * X + rnorm(n)
dl <- data.frame(X, Y, m1 = Ml + rnorm(n, sd = .6),
                 m2 = .9 * Ml + rnorm(n, sd = .6), m3 = 1.1 * Ml + rnorm(n, sd = .6))
lat <- "Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ Ml + X"
t_lat <- triple(lat, dl, c("Ml", "X"), c("Y", "Ml"))
a2 <- quiet(sem("Ml =~ m1 + m2 + m3\nMl ~ 0*X\nY ~ Ml + X", data = dl))
b2 <- quiet(sem("Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ 0*Ml + X", data = dl))
ok("latent: a = 0 fit equals the 0* syntax oracle (1e-9)", abs(t_lat[["a"]] - ll(a2)) < 1e-9)
ok("latent: b = 0 fit equals the 0* syntax oracle (1e-9)", abs(t_lat[["b"]] - ll(b2)) < 1e-9)
ok("latent: k = 1 on both branches (measurement model untouched)",
   all(t_lat[c("k_a", "k_b")] == 1))
st_l <- do.call(rbind, rep(list(dl), 3))
ok("latent: stacked T / K equals the single-dataset T (1e-6)",
   abs(T_union(triple(lat, st_l, c("Ml", "X"), c("Y", "Ml"))) / 3 - T_union(t_lat)) < 1e-6)

# ---- 4. the trap: a bare lavaanify() table is NOT the table sem() fits --------
pt_bare <- lavaanify(lat, auto = TRUE)
full_l <- quiet(sem(lat, data = dl))
ok("trap: lavaanify(auto = TRUE) has more free parameters than sem() fits (latent model)",
   sum(pt_bare$free > 0) > lavInspect(full_l, "npar"))
if (length(failed)) stop(length(failed), " check(s) failed: ", paste(failed, collapse = "; "), call. = FALSE)
