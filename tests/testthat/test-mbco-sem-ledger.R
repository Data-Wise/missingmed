ledger_data <- setNames(iris[1:4], c("X", "M", "Y", "C"))
ledger_model <- "M ~ a*X + C; Y ~ b*M + X + C"

ledger_apis <- function(implist = list(ledger_data, ledger_data), model = ledger_model,
                        baseline = implist[[1L]]) {
  n <- nrow(baseline)
  long <- do.call(rbind, lapply(0:length(implist), function(i) {
    data.frame(.imp = i, .id = seq_len(n), if (i == 0L) baseline else implist[[i]])
  }))
  imp <- withr::with_seed(1, mice::as.mids(long))
  fitted <- run(set_md_mediation(imp, model = model, treatment = "X",
    mediator = "M", outcome = "Y", engine = "lavaan"))
  list(
    mbco_d4 = function(mode) mbco_d4(implist, model = model,
      treatment = "X", mediator = "M", outcome = "Y", ariv = mode),
    infer = function(mode) infer(fitted, type = "mbco", ariv = mode)
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

positions <- c("imputation 1", "imputation 2", "the stacked data")

test_that("nonconverged nulls name the dataset and branch in both public APIs", {
  skip_if_not_installed("medfit", "0.19.0")
  local_mocked_bindings(.mm_sem_fit = ledger_single_start)
  refit <- getFromNamespace(".sem_fit_syntax", "medfit")
  no_convergence <- getFromNamespace(".sem_no_convergence", "medfit")
  for (api in ledger_apis()) for (mode in c("fixed", "own")) {
    for (side in c("a", "b")) for (target in 1:3) local({
      calls <- 0L
      local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
        if (length(model) == 1L && endsWith(model, paste0("\n", side, " == 0"))) {
          calls <<- calls + 1L
          if (calls == target) no_convergence("planted null optimizer failure")
        }
        refit(model, ...)
      }, .package = "medfit")
      dataset <- positions[[target]]
      expect_error(api(mode), paste0("failed in ", dataset, ": The ", side,
        " = 0 model did not converge"), fixed = TRUE)
      expect_identical(calls, target)
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

sides <- c("a", "b")

for (api in c("mbco_d4", "infer")) for (mode in c("fixed", "own")) {
  test_that(paste(api, mode, "clean ledger pools"), {
    skip_if_not_installed("medfit", "0.19.0")
    local_mocked_bindings(.mm_sem_fit = ledger_single_start)
    apis <- ledger_apis(model = "M ~ a*X + C; Y ~ b*M + X")
    expect_true(S7::S7_inherits(apis[[api]](mode), missingmed::MbcoMIResult))
  })
  for (position in seq_along(positions)) for (side in seq_along(sides)) {
    test_that(paste(api, mode, positions[position], sides[side], "negative ledger"), {
      skip_if_not_installed("medfit", "0.19.0")
      apis <- ledger_apis(model = "M ~ a*X + C; Y ~ b*M + X")
      real_mbco <- missingmed:::.mm_sem_medfit_mbco
      real_lr <- missingmed:::.mm_sem_lr
      valid_mbco <- getFromNamespace(".sem_valid_mbco_outcome", "medfit")
      calls <- 0L
      validated <- FALSE
      reached_lr <- FALSE
      target <- paste(sides[side], "== 0")
      planted <- NA_real_
      local_mocked_bindings(
        .mm_sem_fit = ledger_single_start,
        .mm_sem_medfit_mbco = function(fit, a, b) {
          calls <<- calls + 1L
          result <- real_mbco(fit, a, b)
          stopifnot(identical(fit@diagnostics$ledger$context$settings$n_starts, 1L))
          if (calls != position) return(result)

          # Keep the genuine response except for the selected null discrepancy
          # and the fields medfit calculates from it.
          null_f <- fit@f - 0.001 / fit@n_obs
          stopifnot(null_f > 0, identical(result$tests$constraint[side], target))
          result$tests$f[side] <- null_f
          result$tests$diff_ll <- fit@n_obs * (result$tests$f - fit@f)
          result$ledger$children[[side + 1L]]$likelihood$f <- null_f
          result$statistic[[1L]] <- min(result$tests$diff_ll)
          result$p.value <- stats::pchisq(result$statistic[[1L]], df = 1, lower.tail = FALSE)
          planted <<- result$tests$diff_ll[side]
          stopifnot(abs(planted + 0.001) < 1e-12,
                    all(result$tests$diff_ll[-side] >= 0),
                    identical(result$unresolved, FALSE))
          settings <- result$ledger$context$settings[c("n_starts", "control", "se_type")]
          validated <<- isTRUE(valid_mbco(result$ledger, c(a, b),
            settings = settings, tests = result$tests))
          stopifnot(validated)
          result
        },
        .mm_sem_lr = function(x, branch) {
          if (identical(branch, target) && is.finite(x) && x < -1e-7) {
            reached_lr <<- validated && identical(x, planted)
          }
          real_lr(x, branch)
        },
        .package = "missingmed"
      )
      rejection <- paste0("failed in ", positions[position],
        ": Unresolved negative LR for ", target, " \\(-[0-9.eE+-]+ raw LR units\\)\\.")
      expect_error(apis[[api]](mode), rejection)
      expect_true(validated && reached_lr)
    })
  }
}

for (api in c("mbco_d4", "infer")) for (mode in c("fixed", "own")) {
  test_that(paste(api, mode, "pairs typed retention and ordinary failure at stacked a = 0"), {
    skip_if_not_installed("medfit", "0.19.0")
    local_mocked_bindings(.mm_sem_fit = ledger_single_start)
    implist <- list(ledger_data[1:120, ], ledger_data[31:150, ])
    baseline <- implist[[1L]]
    baseline[] <- NA_real_
    apis <- ledger_apis(implist, baseline = baseline)
    n <- nrow(baseline)
    K <- length(implist)
    fault_text <- "injected stack covariance failure"
    ordinary_fault <- simpleError(fault_text)
    expected_path <- rep(c("full", "a", "b"), 3L)

    real_fit <- getFromNamespace(".sem_fit_syntax", "medfit")
    real_vcov <- getFromNamespace(".sem_vcov", "medfit")
    make_diagnostic <- getFromNamespace(".sem_covariance_diagnostic", "medfit")
    typed_fault <- make_diagnostic("information_not_pd", fault_text)
    real_mbco <- missingmed:::.mm_sem_medfit_mbco
    observe <- function(invoke, fault = NULL) {
      warnings <- character()
      visited <- data.frame(rows = integer(), side = character())
      target <- list()
      responses <- list()
      dependency_error <- NULL
      current <- NULL
      track_fit <- function(model, data, ...) {
        stopifnot(identical(list(...)$n_starts, 1L))
        side <- "full"
        if (endsWith(model, "\na == 0")) side <- "a"
        if (endsWith(model, "\nb == 0")) side <- "b"
        current <<- list(model = model, data = data, side = side)
        real_fit(model, data, ...)
      }
      inject_vcov <- function(theta, ...) {
        rows <- nrow(current$data)
        visited[nrow(visited) + 1L, ] <<- list(rows, current$side)
        if (rows == K * n && current$side == "a") {
          target[[length(target) + 1L]] <<- c(current, list(theta = theta))
          if (!is.null(fault)) stop(fault)
        }
        real_vcov(theta, ...)
      }
      track_mbco <- function(fit, a, b) {
        out <- tryCatch(real_mbco(fit, a, b), error = function(e) {
          dependency_error <<- e
          stop(e)
        })
        responses[[length(responses) + 1L]] <<- out
        out
      }
      block_retry <- function(...) stop("Perturbed optimizer starts are forbidden.")
      result <- tryCatch(withCallingHandlers(
        with_mocked_bindings(
          with_mocked_bindings(invoke(), .mm_sem_medfit_mbco = track_mbco, .package = "missingmed"),
          .sem_fit_syntax = track_fit, .sem_vcov = inject_vcov,
          .sem_perturbed_starts = block_retry, .package = "medfit"),
        warning = function(w) {
          warnings <<- c(warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }), error = identity)
      list(result = result, warnings = warnings, visited = visited, target = target,
        responses = responses, dependency_error = dependency_error)
    }

    invoke <- function() apis[[api]](mode)
    clean <- observe(invoke)
    retained <- observe(invoke, typed_fault)
    refused <- observe(invoke, ordinary_fault)

    expect_true(S7::S7_inherits(clean$result, missingmed::MbcoMIResult))
    expect_identical(clean$warnings, character())
    expect_gt(clean$result[["r4"]], 0)
    expect_identical(clean$visited$side, expected_path)
    expect_identical(clean$visited$rows, rep(c(n, n, K * n), each = 3L))
    expect_length(clean$target, 1L)
    expect_identical(retained$visited, clean$visited)
    expect_identical(retained$target, clean$target)
    expect_identical(refused$target, clean$target)
    expect_identical(refused$visited, head(clean$visited, -1L))

    expect_identical(retained$result, clean$result)
    expect_identical(retained$warnings, paste0("SEM MBCO warnings: the stacked data: ",
      "a = 0 covariance-stage failure: ", fault_text, "; likelihood retained, covariance unavailable"))
    expect_identical(lapply(retained$responses, function(x) x$tests),
      lapply(clean$responses, function(x) x$tests))
    ledger <- retained$responses[[3L]]$ledger
    node <- ledger$children[[2L]]
    expect_identical(ledger$schema_version, 1L)
    expect_identical(node$id, "mbco/null:1")
    expect_identical(node$outcome, "resolved")
    expect_identical(node$likelihood, clean$responses[[3L]]$ledger$children[[2L]]$likelihood)
    expect_identical(node$covariance, "failed")
    expect_identical(node$post_fit$stage, "covariance")
    expect_identical(node$post_fit$condition$kind, "information_not_pd")
    expect_identical(ledger$children[[3L]], clean$responses[[3L]]$ledger$children[[3L]])

    expect_identical(refused$dependency_error, ordinary_fault)
    expect_s3_class(refused$result, "error")
    expect_identical(conditionMessage(refused$result),
      paste0("Fitting the MBCO models failed in the stacked data: ", fault_text))
    expect_identical(refused$warnings, character())
    expect_identical(refused$responses, clean$responses[1:2])
  })
}
