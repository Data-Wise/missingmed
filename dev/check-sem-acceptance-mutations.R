# T5 deterministic controls: in-memory defects, never saved-result rewrites.
devtools::load_all()
source("tests/testthat/helper-legacy-mbco.R")
target <- "tests/testthat/test-mbco-sem-acceptance.R"
pool_original <- missingmed:::.mm_d4_pool
df_original <- missingmed:::.mm_d4_from_stats
provider_original <- missingmed:::.mm_sem_provider
fit_original <- missingmed:::.mm_sem_fit
label_original <- missingmed:::.mm_sem_label_model
attribution_original <- missingmed:::.mm_sem_attribute_nulls
refit_original <- missingmed:::.mm_sem_refit_diagnostics
mutate_body <- function(fun, old, new) {
  text <- paste(deparse(body(fun)), collapse = "\n")
  stopifnot(grepl(old, text, fixed = TRUE))
  body(fun) <- parse(text = gsub(old, new, text, fixed = TRUE))[[1L]]
  fun
}
run_test <- function() testthat::test_file(target, reporter = "silent")
mutations <- c("li_df", "stack_divisor", "tie", "diagnostic_labels",
  "dimensions", "factor_limit", "improper_payload", "encoding", "syntax",
  "null_identity", "null_lr_match", "full_fixed_x", "null_factors", "null_fixed_x",
  "survivor_complete", "table_converged", "table_finite", "empty_improper", "null_nobs")
intended <- c(
  li_df = "independent K=20 answers distinguish Chan-Meng from historical Li df",
  stack_divisor = "encoding, own/fixed selection, ties and labeled diagnostics are independent",
  tie = "encoding, own/fixed selection, ties and labeled diagnostics are independent",
  diagnostic_labels = "encoding, own/fixed selection, ties and labeled diagnostics are independent",
  dimensions = "encoding, own/fixed selection, ties and labeled diagnostics are independent",
  factor_limit = "binary covariates match numeric coding but three-level factors refuse",
  improper_payload = "full improper diagnostics retain medfit's character payload and warn once",
  encoding = "stored fixture cross-check retains separate legacy and df provenance",
  syntax = "parser normalization cannot admit explicitly excluded syntax",
  null_identity = "null attribution uses refit identity rather than warning count in both APIs",
  null_lr_match = "unidentified null warnings require matching branch diagnostic refits",
  full_fixed_x = "diagnostic state guards reject mismatches before public pooling",
  null_factors = "diagnostic state guards reject mismatches before public pooling",
  null_fixed_x = "diagnostic state guards reject mismatches before public pooling",
  survivor_complete = "public incomplete refits never become a successful survivor",
  table_converged = "public incomplete refits never become a successful survivor",
  table_finite = "public incomplete refits never become a successful survivor",
  empty_improper = "null attribution uses refit identity rather than warning count in both APIs",
  null_nobs = "unidentified null warnings require matching branch diagnostic refits")
selected <- commandArgs(trailingOnly = TRUE)
if (length(selected)) {
  stopifnot(all(selected %in% mutations))
  mutations <- selected
}
for (mutation in mutations) {
  result <- switch(mutation,
    survivor_complete = testthat::with_mocked_bindings(run_test(),
      .mm_sem_provider = mutate_body(provider_original,
        "tab <- mb$tests", paste0("tab <- mb$tests\n",
          "if (is.data.frame(tab) && nrow(tab) > 0L && any(tab$converged %in% TRUE) && ",
          "(nrow(tab) == 1L || !all(tab$converged %in% TRUE))) {\n",
          "tab <- tab[rep(which(tab$converged %in% TRUE)[1L], 2L), ]\n",
          "tab$constraint <- paste(c(lab$a, lab$b), '== 0')\n}")),
      .package = "missingmed"),
    table_converged = testthat::with_mocked_bindings(run_test(),
      .mm_sem_provider = mutate_body(provider_original, "!all(tab$converged %in% TRUE)", "FALSE"),
      .package = "missingmed"),
    table_finite = testthat::with_mocked_bindings(run_test(),
      .mm_sem_provider = mutate_body(provider_original, "any(!is.finite(tab$f))", "FALSE"),
      .package = "missingmed"),
    empty_improper = testthat::with_mocked_bindings(run_test(),
      .mm_sem_provider = mutate_body(provider_original,
        "length(mb$improper)", "as.integer(!is.null(mb$improper))"),
      .package = "missingmed"),
    null_nobs = testthat::with_mocked_bindings(run_test(),
      .mm_sem_attribute_nulls = mutate_body(attribution_original,
        "!identical(as.numeric(null$n_obs), as.numeric(fit@n_obs))", "FALSE"),
      .package = "missingmed"),
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
        for (nm in names(d)) {
          if (is.factor(d[[nm]]) && nlevels(d[[nm]]) > 2L) d[[nm]] <- as.numeric(d[[nm]]) - 1
        }
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
        "invisible(lapply(as.list(expressions), check))", "NULL"), .package = "missingmed"),
    null_identity = testthat::with_mocked_bindings(run_test(),
      .mm_sem_attribute_nulls = function(...) {
        mb <- attribution_original(...)
        mb$improper <- "a"
        mb
      }, .package = "missingmed"),
    full_fixed_x = testthat::with_mocked_bindings(run_test(),
      .mm_sem_refit_diagnostics = mutate_body(refit_original,
        "length(fit@internals$fixed_x)", "FALSE"), .package = "missingmed"),
    null_factors = testthat::with_mocked_bindings(run_test(),
      .mm_sem_refit_diagnostics = mutate_body(refit_original,
        "!identical(null@internals$factors, fit@internals$factors)", "FALSE"),
      .package = "missingmed"),
    null_fixed_x = testthat::with_mocked_bindings(run_test(),
      .mm_sem_refit_diagnostics = mutate_body(refit_original,
        "!identical(null@internals$fixed_x, fit@internals$fixed_x)", "FALSE"),
      .package = "missingmed"),
    null_lr_match = testthat::with_mocked_bindings(run_test(),
      .mm_sem_attribute_nulls = mutate_body(attribution_original,
        "abs(lr - tab$diff_ll[i]) > 1e-07", "FALSE"), .package = "missingmed")
  )
  result <- as.data.frame(result)
  hit <- result$test == intended[[mutation]]
  cat(mutation, "intended assertion failures:", sum(result$failed[hit]),
    "execution errors:", sum(result$error), "\n")
  if (any(result$error)) print(result[result$error, c("test", "error")])
  stopifnot(any(hit), sum(result$failed[hit]) > 0, !any(result$error))
}
