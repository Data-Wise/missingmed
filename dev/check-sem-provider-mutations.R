# Deterministic mutation receipt. Run with the existing compatible R_LIBS.
devtools::load_all()
original <- missingmed:::.mm_sem_mbco
lr_original <- missingmed:::.mm_sem_lr
target <- "tests/testthat/test-mbco-sem-provider.R"
intended <- c(
  lr = "SEM provider validates both branches before pooling in either ARIV mode",
  completeness = "unledgered union routes are refused before any fitting",
  labels = "stored observed and latent data agree with the lavaan branch oracle",
  feasibility = "joint variance feasibility and redundant equality consistency fail closed",
  args = "SEM fit_args refuses unknown and likelihood-changing options by name")
for (mutation in c("lr", "completeness", "labels", "feasibility", "args")) {
  result <- switch(mutation,
    args = testthat::with_mocked_bindings(
      testthat::test_file("tests/testthat/test-mbco-sem-args.R", reporter = "silent"),
      .mm_sem_check_args = function(...) invisible(TRUE), .package = "missingmed"),
    lr = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_lr = function(x, branch) lr_original(abs(x), branch), .package = "missingmed"),
    completeness = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_complete_syntax = function(model) invisible(TRUE), .package = "missingmed"),
    feasibility = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_feasible = function(...) TRUE, .package = "missingmed"),
    labels = testthat::with_mocked_bindings(
      testthat::test_file(target, reporter = "silent"),
      .mm_sem_mbco = function(fit, a, b) {
        out <- original(fit, b, a)
        # Hide the swap from the table-label guard, testing the numerical oracle.
        out$tests$constraint <- paste(c(a, b), "== 0")
        out
      }, .package = "missingmed")
  )
  result <- as.data.frame(result)
  hit <- result$test == intended[[mutation]]
  cat(mutation, "intended assertion failures:", sum(result$failed[hit]),
    "execution errors:", sum(result$error), "\n")
  if (any(result$error)) print(result[result$error, c("test", "result")])
  stopifnot(any(hit), sum(result$failed[hit]) > 0, !any(result$error))
}
