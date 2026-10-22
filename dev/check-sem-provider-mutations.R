# Deterministic mutation receipt. Run with the existing compatible R_LIBS.
devtools::load_all()
original <- missingmed:::.mm_sem_mbco
target <- "tests/testthat/test-mbco-sem-provider.R"
for (mutation in c("lr", "completeness", "labels", "feasibility", "args")) {
  result <- switch(mutation,
    args = testthat::with_mocked_bindings(
      testthat::test_file("tests/testthat/test-mbco-sem-args.R", reporter = "silent"),
      .mm_sem_check_args = function(...) invisible(TRUE), .package = "missingmed"),
    lr = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_lr = function(x, branch) abs(x), .package = "missingmed"),
    completeness = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_complete_syntax = function(model) invisible(TRUE), .package = "missingmed"),
    feasibility = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_feasible = function(...) TRUE, .package = "missingmed"),
    labels = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_mbco = function(fit, a, b) original(fit, b, a), .package = "missingmed")
  )
  result <- as.data.frame(result)
  failures <- sum(result$failed) + sum(result$error)
  cat(mutation, "detected failures/errors:", failures, "\n")
  stopifnot(failures > 0)
}
