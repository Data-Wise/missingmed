ledger_data <- setNames(iris[1:4], c("X", "M", "Y", "C"))
ledger_model <- "M ~ a*X + C; Y ~ b*M + X + C"

ledger_apis <- function() {
  long <- do.call(rbind, lapply(0:2, function(i) {
    data.frame(.imp = i, .id = seq_len(nrow(ledger_data)), ledger_data)
  }))
  imp <- withr::with_seed(1, mice::as.mids(long))
  fitted <- run(set_md_mediation(imp, model = ledger_model, treatment = "X",
    mediator = "M", outcome = "Y", engine = "lavaan"))
  list(
    direct = function(mode) mbco_d4(list(ledger_data, ledger_data), model = ledger_model,
      treatment = "X", mediator = "M", outcome = "Y", ariv = mode),
    wrapped = function(mode) infer(fitted, type = "mbco", ariv = mode)
  )
}

ledger_single_start <- function(model, d) {
  fit <- medfit::fit_sem(model, d, fixed_x = FALSE, meanstructure = NULL, n_starts = 1L)
  list(fit = fit, n_obs = fit@n_obs, improper = fit@diagnostics$improper)
}

test_that("both public APIs name the exact retained null once in each ARIV mode", {
  skip_if_not_installed("medfit", "0.19.0")
  local_mocked_bindings(.mm_sem_fit = ledger_single_start)
  real_vcov <- getFromNamespace(".sem_vcov", "medfit")
  for (api in ledger_apis()) for (mode in c("fixed", "own")) {
    clean <- api(mode)
    for (i in 1:2) local({
      calls <- 0L
      local_mocked_bindings(.sem_vcov = function(...) {
        calls <<- calls + 1L
        if (calls == i + 1L) {
          stop(structure(list(message = "planted covariance diagnostic", call = NULL,
            kind = "information_not_pd"), class = c("medfit_sem_covariance_diagnostic", "error", "condition")))
        }
        real_vcov(...)
      }, .package = "medfit")
      warnings <- capture_warnings(result <- api(mode))
      side <- c("a", "b")[i]
      expect_identical(warnings, paste0("SEM MBCO warnings: imputation 1: ", side,
        " = 0 covariance-stage failure: planted covariance diagnostic; likelihood retained, covariance unavailable"))
      expect_identical(result, clean)
    })
  }
})

test_that("unknown, incomplete and mismatched ledgers refuse both public APIs and ARIV modes", {
  skip_if_not_installed("medfit", "0.19.0")
  real <- missingmed:::.mm_sem_medfit_mbco
  local_mocked_bindings(.mm_sem_fit = ledger_single_start)
  mutations <- list(
    function(x) { x$ledger <- NULL; x },
    function(x) { x$ledger$schema_version <- 2L; x },
    function(x) { x$ledger$children[[2L]]$schema_version <- 2L; x },
    function(x) { x$ledger$children[[3L]] <- NULL; x },
    function(x) { x$ledger$children <- x$ledger$children[c(1L, 3L, 2L)]; x },
    function(x) { x$ledger$children[[2L]]$children <- list(list(outcome = "unresolved")); x },
    function(x) { x$ledger$children[[2L]]$outcome <- "unresolved"; x },
    function(x) { x$ledger$children[[2L]]$improper <- NULL; x },
    function(x) { x$ledger$children[[2L]]$notices <- NULL; x },
    function(x) { x$ledger$children[[2L]]$context$sample_hash <- "other rows"; x },
    function(x) { x$ledger$children[[2L]]$context$settings$n_starts <- 4L; x },
    function(x) { x$ledger$children[[2L]]$constraints$lhs <- "b"; x },
    function(x) { x$ledger$children[[2L]]$covariance <- "failed"; x },
    function(x) { x$tests$diff_ll[1L] <- x$tests$diff_ll[1L] + 1; x }
  )
  apis <- ledger_apis()
  for (api in apis) for (mode in c("fixed", "own")) {
    for (mutate in mutations) local({
      local_mocked_bindings(.mm_sem_medfit_mbco = function(fit, a, b) mutate(real(fit, a, b)))
      expect_error(api(mode), "imputation 1.*(SEM outcome ledger|SEM covariance evidence)")
    })
    local({
      calls <- 0L
      local_mocked_bindings(.mm_sem_medfit_mbco = function(fit, a, b) {
        calls <<- calls + 1L
        result <- real(fit, a, b)
        if (calls == 3L) result$ledger$children[[2L]]$enumeration$state <- "not_enumerated"
        result
      })
      expect_error(api(mode), "stacked data.*Incomplete or unresolved SEM outcome ledger")
    })
    local({
      local_mocked_bindings(.mm_sem_fit = function(model, d) {
        fit <- ledger_single_start(model, d)
        fit$fit@diagnostics$ledger <- NULL
        fit
      })
      expect_error(api(mode), "imputation 1.*Missing or unknown SEM outcome ledger schema for fit")
    })
  }
})
