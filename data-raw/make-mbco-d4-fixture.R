# Freeze the D4-MBCO fixture used by tests/testthat/test-mbco-ariv.R.
#
# Expected values come from medsim 0.5.1, whose medsim_method_mbco_mi() already
# implements both ARIV variants (`.medsim_d4_mbco(fixed_branch = FALSE/TRUE)`).
# The fixture is a static .rds, so missingmed neither Imports nor Suggests
# medsim; this script is the only place medsim is called.
#
# Data are synthetic: a gaussian X -> M -> Y model with one covariate C1, MAR
# missingness on M (driven by X) and on Y (driven by C1), imputed with
# mice(method = "norm", m = 5). The seeds were picked because the imputations
# disagree on the winning MBCO branch, so "own" and "fixed" differ. The stacked
# fit picks the b = 0 branch in seeds 26 and 9 and the a = 0 branch in seed 28.
# In seeds 26 and 28 the own-branch r4 clamps to 0, so nu = Inf there.
#
# `legacy_own` is infer(type = "mbco") from missingmed 0.4.0.9000 (dev at
# ff64297, before the ariv argument existed), recorded so the tests can check
# that ariv = "own" reproduces it bit for bit. It cannot be regenerated once
# the change is in, so a rerun keeps the stored value.
#
# Run from the package root: Rscript data-raw/make-mbco-d4-fixture.R

stopifnot(packageVersion("medsim") == "0.5.1")
out_file <- "tests/testthat/fixtures/mbco-d4-medsim-0.5.1.rds"

gen_case <- function(seed, n = 200, a = 0.15, b = 0.15, m = 5) {
  set.seed(seed)
  C1 <- rnorm(n)
  X <- rnorm(n)
  M <- a * X + 0.3 * C1 + rnorm(n)
  Y <- b * M + 0.2 * X + 0.3 * C1 + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C1 = C1)
  d$M[runif(n) < plogis(-1.2 + 0.8 * d$X)] <- NA
  d$Y[runif(n) < plogis(-1.2 + 0.8 * d$C1)] <- NA
  imp <- mice::mice(d, m = m, method = "norm", printFlag = FALSE, seed = seed)
  implist <- unclass(mice::complete(imp, "all"))

  own <- medsim:::.medsim_d4_mbco(implist, "C1", fixed_branch = FALSE)
  fix <- medsim:::.medsim_d4_mbco(implist, "C1", fixed_branch = TRUE)
  branches <- vapply(implist, function(x) medsim:::.medsim_mbco_branch(x, "C1"), 0)
  keep <- c("D4", "p", "r4", "nu")
  list(
    seed = seed, mids = imp, implist = implist,
    formula_y = Y ~ X + M + C1, formula_m = M ~ X + C1,
    expected = list(own = own[keep], fixed = fix[keep]),
    # medsim codes the branch 1 = (a = 0), 0 = (b = 0).
    stacked_branch = if (fix[["stacked_branch"]] == 1) "a" else "b",
    p_branch_a = mean(branches),
    branch_mix = length(unique(branches)) > 1L
  )
}

cases <- lapply(c(seed26 = 26, seed9 = 9, seed28 = 28), gen_case)

old <- if (file.exists(out_file)) readRDS(out_file) else NULL
pkgload::load_all(".", quiet = TRUE)
for (nm in names(cases)) {
  cases[[nm]]$legacy_own <- if (!exists("mbco_d4", asNamespace("missingmed"))) {
    md <- set_md_mediation(cases[[nm]]$mids, cases[[nm]]$formula_y,
      cases[[nm]]$formula_m, treatment = "X", mediator = "M")
    infer(run(md), type = "mbco")
  } else {
    old$cases[[nm]]$legacy_own
  }
  stopifnot(is.double(cases[[nm]]$legacy_own), !is.object(cases[[nm]]$legacy_own))
}

dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
saveRDS(list(
  medsim_version = "0.5.1", mice_version = as.character(packageVersion("mice")),
  R_version = R.version.string, cases = cases
), out_file, version = 2)
