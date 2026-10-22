# T5 deterministic controls: in-memory defects, never saved-result rewrites.
devtools::load_all()
source("tests/testthat/helper-legacy-mbco.R")
target <- "tests/testthat/test-mbco-sem-acceptance.R"
pool_original <- missingmed:::.mm_d4_pool
df_original <- missingmed:::.mm_d4_from_stats
provider_original <- missingmed:::.mm_sem_provider
fit_original <- missingmed:::.mm_sem_fit
label_original <- missingmed:::.mm_sem_label_model
mutate_body <- function(fun, old, new) {
  text <- paste(deparse(body(fun)), collapse = "\n")
  stopifnot(grepl(old, text, fixed = TRUE))
  body(fun) <- parse(text = gsub(old, new, text, fixed = TRUE))[[1L]]
  fun
}
run_test <- function() testthat::test_file(target, reporter = "silent")
for (mutation in c("li_df", "stack_divisor", "tie", "diagnostic_labels",
  "dimensions", "factor_limit", "improper_payload", "encoding", "syntax")) {
  result <- switch(mutation,
    li_df = testthat::with_mocked_bindings(run_test(),
      .mm_d4_from_stats = function(d_k, d_S, k = 1) {
        out <- df_original(d_k, d_S, k)
        t <- k * (length(d_k) - 1)
        if (t > 4 && out[["r4"]] > 0) {
          out["nu"] <- 4 + (t - 4) * (1 + (1 - 2 / t) / out[["r4"]])^2
          out["p"] <- stats::pf(out[["D4"]], k, out[["nu"]], lower.tail = FALSE)
        }
        out
      }, .package = "missingmed"),
    stack_divisor = testthat::with_mocked_bindings(run_test(),
      .mm_d4_pool = mutate_body(pool_original, "/K", "/1"), .package = "missingmed"),
    tie = testthat::with_mocked_bindings(run_test(),
      .mm_d4_pool = mutate_body(pool_original, ">=", ">"), .package = "missingmed"),
    diagnostic_labels = testthat::with_mocked_bindings(run_test(),
      .mm_d4_pool = function(...) {
        r <- pool_original(...)
        r@stacked_branch <- if (r@stacked_branch == "a") "b" else "a"
        r@p_branch_a <- 1 - r@p_branch_a
        r
      }, .package = "missingmed"),
    dimensions = testthat::with_mocked_bindings(run_test(),
      .mm_d4_pool = mutate_body(mutate_body(pool_original,
        "length(ks) > 1L", "FALSE"), "k_i != k_S", "FALSE"), .package = "missingmed"),
    factor_limit = testthat::with_mocked_bindings(run_test(),
      .mm_sem_fit = function(model, d) {
        for (nm in names(d)) if (is.factor(d[[nm]])) d[[nm]] <- as.numeric(d[[nm]]) - 1
        fit_original(model, d)
      }, .package = "missingmed"),
    improper_payload = testthat::with_mocked_bindings(run_test(),
      .mm_sem_provider = function(...) {
        p <- provider_original(...)
        function(d) { z <- p(d); attr(z, "improper") <- character(); z }
      }, .package = "missingmed"),
    encoding = testthat::with_mocked_bindings(run_test(),
      .mm_sem_provider = function(...) {
        p <- provider_original(...)
        function(d) { z <- p(d); z[c("a", "b")] <- 2 * z[c("a", "b")]; z }
      }, .package = "missingmed"),
    syntax = testthat::with_mocked_bindings(run_test(),
      .mm_sem_label_model = mutate_body(label_original,
        "invisible(lapply(as.list(expressions), check))", "NULL"), .package = "missingmed")
  )
  result <- as.data.frame(result)
  failures <- sum(result$failed) + sum(result$error)
  cat(mutation, "detected failures/errors:", failures, "\n")
  stopifnot(failures > 0)
}
