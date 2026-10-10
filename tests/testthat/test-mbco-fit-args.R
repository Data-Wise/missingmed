# infer(type = "mbco") refits with bare stats::glm(), so a fit_args entry that
# changes the likelihood must be refused rather than silently ignored
# (PLAN-codex-review-fixes F2).

skip_if_not_installed("mice")

fw_data <- function(n = 150, seed = 17) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rnorm(n)
  M <- .5 * X + .3 * C + rnorm(n)
  Y <- .4 * M + .2 * X + .3 * C + rnorm(n)
  d <- data.frame(X, M, Y, C)
  d$M[1:25] <- NA
  d
}
fw_imp <- local({
  mice::mice(fw_data(), m = 2, maxit = 2, method = "norm", printFlag = FALSE, seed = 3)
})
fw_w <- local({
  set.seed(9)
  runif(150, .3, 3)
})
fw_fit <- function(...) {
  run(set_md_mediation(fw_imp, Y ~ X + M + C, M ~ X + C,
    treatment = "X", mediator = "M", ...
  ))
}

test_that("MBCO refuses weights in fit_args, and the control run still works", {
  fit <- fw_fit(fit_args = list(weights = fw_w))
  expect_error(infer(fit, type = "mbco"), "cannot honor `weights`")
  expect_no_error(infer(fit, type = "mc", n.mc = 2000))
})

test_that("MBCO refuses each likelihood-changing entry, naming it", {
  fit <- fw_fit(fit_args = list(weights = fw_w))
  for (nm in c("weights", "offset", "subset", "na.action")) {
    src <- fit@source
    src@fit_args <- stats::setNames(list(NULL), nm)
    fit2 <- fit
    fit2@source <- src
    expect_error(infer(fit2, type = "mbco"), paste0("`", nm, "`"))
  }
})

test_that("MBCO without fit_args, and with a convergence-only entry, is unchanged", {
  base <- infer(fw_fit(), type = "mbco")
  ctrl <- infer(fw_fit(fit_args = list(control = list(maxit = 50))), type = "mbco")
  expect_equal(unname(ctrl["p"]), unname(base["p"]))
})
