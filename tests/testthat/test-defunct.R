# The S4 API removed in 0.6.0 (PLAN T8, H2): stubs name their replacement.

test_that("each defunct function stops, naming its replacement", {
  cases <- list(
    set_sem = "set_md_mediation",
    run_sem = "run()",
    pool_sem = "pool()",
    fit_model = "run()",
    lav_mice = "engine = \"lavaan\"",
    mx_mice = "no replacement"
  )
  for (nm in names(cases)) {
    f <- get(nm, envir = asNamespace("missingmed"))
    expect_error(f(1), "was removed in missingmed 0.6.0", info = nm)
    expect_error(f(1), cases[[nm]], fixed = TRUE, info = nm)
    expect_error(f(1), "s4-migration", fixed = TRUE, info = nm)
    expect_s3_class(tryCatch(f(1), error = identity), "defunctError")
  }
})

test_that("the deleted S4 symbols are gone from the namespace", {
  ns <- asNamespace("missingmed")
  gone <- c("is_fit", "is_pd", "is_lav_syntax", "is_valid_lav_syntax")
  for (g in gone) expect_false(exists(g, envir = ns, inherits = FALSE), info = g)
  expect_false(methods::isClass("SemImputedData"))
  expect_false(methods::isClass("SemResults"))
  expect_false(methods::isClass("PooledSEMResults"))
})

test_that("n_imp() still reports m for a mids object and refuses anything else", {
  skip_if_not_installed("mice")
  imp <- suppressWarnings(mice::mice(mice::nhanes, m = 3, printFlag = FALSE, seed = 1))
  expect_equal(n_imp(imp), 3)
  expect_error(n_imp(data.frame(a = 1)), "not a 'mids' object")
})

test_that("set_md_mediation() still builds an MI object after the S4 removal", {
  skip_if_not_installed("mice")
  d <- mice::nhanes
  imp <- suppressWarnings(mice::mice(d, m = 2, printFlag = FALSE, seed = 1, maxit = 1))
  md <- set_md_mediation(imp, chl ~ age + bmi, bmi ~ age, treatment = "age", mediator = "bmi")
  expect_identical(md@n_imputations, 2)
})

test_that("the print methods work in a fresh R session on the installed-style namespace (H3)", {
  skip_on_cran()
  skip_if_not_installed("mice")
  # Under R CMD check the package is installed; under devtools::test() load the
  # source tree. Either way a fresh R process, which load_all() in this process
  # cannot stand in for.
  checking <- nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_"))
  if (!checking) skip_if_not_installed("pkgload")
  pkg <- normalizePath(test_path("..", ".."))
  if (!checking) skip_if_not(file.exists(file.path(pkg, "DESCRIPTION")))
  loader <- if (checking) {
    "suppressMessages(library(missingmed))"
  } else {
    "suppressMessages(pkgload::load_all(commandArgs(TRUE)[1], quiet = TRUE))"
  }
  script <- tempfile(fileext = ".R")
  writeLines(c(
    loader,
    "set.seed(1); n <- 120",
    "d <- data.frame(X = rbinom(n, 1, .5), C = rnorm(n))",
    "d$M <- .5 * d$X + rnorm(n); d$Y <- .4 * d$M + .2 * d$X + rnorm(n)",
    "d$M[1:15] <- NA",
    "imp <- suppressWarnings(mice::mice(d, m = 2, maxit = 1, printFlag = FALSE, seed = 1))",
    "md <- set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = 'X', mediator = 'M')",
    "fit <- run(md); res <- pool(fit)",
    "mb <- infer(fit, type = 'mbco')",
    "print(md); print(fit); print(res); print(mb)"
  ), script)
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c(shQuote(script), shQuote(pkg)),
    stdout = TRUE, stderr = TRUE
  ))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "<MDMediationData>", fixed = TRUE)
  expect_match(txt, "<MDMediationFit>", fixed = TRUE)
  expect_match(txt, "<MDMediationResult>", fixed = TRUE)
  expect_match(txt, "MbcoMIResult", fixed = TRUE)
  expect_false(grepl("Error", txt))
})
