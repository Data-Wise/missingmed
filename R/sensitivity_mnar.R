#' MNAR sensitivity analysis by delta-adjusted imputation
#'
#' Re-imputes the data across a grid of delta values and re-runs the mediation
#' pipeline at each rung, producing a **sensitivity curve** for the indirect
#' effect. It is not an estimator: MAR versus MNAR is not testable from observed
#' data, so nothing here is identified. A rung answers "if the unobserved values
#' of `target` sit delta units away from what MAR imputation implies, the
#' indirect effect is X".
#'
#' @section Method:
#' Delta-adjusted imputation in the pattern-mixture sense (van Buuren, *FIMD*
#' §9.2; Leacy et al. 2017). For a continuous target the canonical procedure
#' imputes under MAR and then adds the constant to the imputed values (Hayati
#' Rezvan et al. 2018), which is what this function does via `mice`'s `post`
#' argument. Each rung re-imputes from the `mids` object's stored settings --
#' never from its recorded `call`, which does not resolve outside the function
#' that built it.
#'
#' @section The delta scale (read this before choosing a value):
#' `delta` is a **conditional** sensitivity parameter (CSP): a difference
#' conditional on all remaining variables and their missingness indicators.
#' The quantity an analyst can actually reason about -- "non-respondents average
#' delta units higher" -- is a **marginal** sensitivity parameter (MSP), and the
#' two are different numbers. Supplying an elicited MSP as if it were a CSP is
#' the standard failure mode of this method and can badly damage coverage
#' (Tompsett et al. 2018). This function therefore reports the **realized MSP**
#' at every rung; compare it against what you meant.
#'
#' @section Limitations:
#' * Only `method = "mi"`. IPW has no imputations to shift.
#' * Continuous targets only; see Details for categorical.
#' * With `pmm` (mice's default), shifted values may fall outside the observed
#'   range that `pmm` otherwise guarantees. A message is emitted once.
#' * The curve assumes the supplied imputation model is compatible with the
#'   mediation model; missingmed cannot verify this.
#'
#' @param object An [MDMediationData] with `method = "mi"`.
#' @param delta Numeric vector (one rung per value, applied to `target`), or a
#'   data frame (one rung per row, one column per target variable).
#' @param target Name of the variable to shift. Defaults to the mediator. Must
#'   be `NULL` when `delta` is a data frame.
#' @param type Inference per rung: `"mc"` (default) or `"mbco"`.
#' @param seed Integer seed pinned across rungs. Defaults to the seed stored in
#'   the `mids` object, or `20260822L` when that is `NA`.
#' @param level,n.mc Passed to [infer()].
#' @param ... Passed to [run()].
#'
#' @return An [MDSensitivityResult].
#' @seealso [infer()], [MDSensitivityResult]
#' @export
sensitivity_mnar <- function(object, delta, target = NULL,
                             type = c("mc", "mbco"), seed = NULL,
                             level = 0.95, n.mc = 1e5, ...) {
  type <- match.arg(type)
  if (!S7::S7_inherits(object, MDMediationData)) {
    stop("`object` must be an MDMediationData (from set_md_mediation()).",
      call. = FALSE
    )
  }
  if (identical(object@method, "ipw")) {
    stop("MNAR sensitivity analysis is not available for method = \"ipw\": ",
      "delta adjustment shifts imputed values, and IPW has none. A weighting ",
      "analogue would perturb the missingness model instead -- a different ",
      "method with a different sensitivity parameter, not implemented here.",
      call. = FALSE
    )
  }
  mids <- object@data
  if (!inherits(mids, "mids")) {
    stop("`object@data` must be a mice::mids object for MNAR sensitivity.",
      call. = FALSE
    )
  }

  grid <- .mnar_grid(delta, target, object)
  targets <- names(grid)
  .mnar_check_targets(targets, mids)

  seed_source <- "argument"
  if (is.null(seed)) {
    if (is.numeric(mids$seed) && length(mids$seed) == 1L && !is.na(mids$seed)) {
      seed <- mids$seed
      seed_source <- "mids"
    } else {
      seed <- 20260822L
      seed_source <- "default"
    }
  }

  meth <- unname(mids$method[targets])
  for (v in targets[meth == "pmm"]) {
    message(
      "sensitivity_mnar(): target '", v, "' is imputed by 'pmm'. ",
      "The shift is applied to the imputed values, so they may fall outside ",
      "the observed range that pmm otherwise guarantees."
    )
  }

  rungs <- vector("list", nrow(grid))
  msp <- numeric(nrow(grid))
  for (i in seq_len(nrow(grid))) {
    imp_i <- .mnar_reimpute(mids, grid[i, , drop = FALSE], seed)
    # msp is reported for the first target only; a multi-target grid shifts
    # every named column, but the marginal summary tracks targets[1].
    msp[i] <- .mnar_realized_msp(imp_i, targets[1])
    obj_i <- object
    obj_i@data <- imp_i
    obj_i@mechanism <- "mnar"
    fit_i <- run(obj_i, ...)
    rungs[[i]] <- if (type == "mc") {
      infer(pool(fit_i), type = "mc", level = level, n.mc = n.mc)
    } else {
      infer(fit_i, type = "mbco")
    }
  }

  MDSensitivityResult(
    rungs = rungs, grid = grid, msp = msp, target = targets,
    type = type, seed = seed, seed_source = seed_source,
    method_target = meth, source = object
  )
}

# Build the delta grid: numeric vector -> one column named for `target`;
# data frame -> used as given, its column names naming the targets.
.mnar_grid <- function(delta, target, object) {
  if (is.data.frame(delta)) {
    if (!is.null(target)) {
      stop("`target` must be NULL when `delta` is a data frame; its column ",
        "names name the targets.",
        call. = FALSE
      )
    }
    if (!nrow(delta) || !ncol(delta)) {
      stop("`delta` data frame must have at least one row and one column.",
        call. = FALSE
      )
    }
    return(as.data.frame(delta))
  }
  if (!is.numeric(delta) || !length(delta)) {
    stop("`delta` must be a non-empty numeric vector or a data frame.",
      call. = FALSE
    )
  }
  if (is.null(target)) target <- object@mediator
  if (length(target) != 1L) {
    stop("`target` must name exactly one variable when `delta` is a vector.",
      call. = FALSE
    )
  }
  out <- data.frame(delta)
  names(out) <- target
  out
}

# A target must exist, actually be incomplete, and be continuous.
.mnar_check_targets <- function(targets, mids) {
  d <- mids$data
  for (v in targets) {
    if (!v %in% names(d)) {
      stop("Target '", v, "' is not a column of the imputed data.", call. = FALSE)
    }
    if (is.na(mids$method[v])) {
      stop("Target '", v, "' has no imputation method of its own: it is part of ",
        "a multivariate block. Delta adjustment needs a per-variable method.",
        call. = FALSE
      )
    }
    if (!isTRUE(mids$nmis[[v]] > 0)) {
      stop("Target '", v, "' has no missing values, so a delta on it would do ",
        "nothing. Check the target name.",
        call. = FALSE
      )
    }
    if (is.factor(d[[v]]) || is.logical(d[[v]]) || is.character(d[[v]]) ||
      unname(mids$method[v]) %in% c("logreg", "polyreg", "polr", "lda")) {
      stop("Target '", v, "' is categorical (or imputed by a categorical ",
        "method). An additive shift on drawn 0/1 values is not meaningful. ",
        "The correct construction offsets the imputation model's linear ",
        "predictor, with delta on the odds-ratio scale -- not yet implemented.",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

# Re-impute from the mids object's STORED SETTINGS (never mids$call, which
# references the caller's local symbols), composing the delta into any post
# expressions the user already had.
.mnar_reimpute <- function(mids, row, seed) {
  post <- mids$post
  for (v in names(row)) {
    line <- sprintf("imp[[j]][, i] <- imp[[j]][, i] + (%s)", format(row[[v]], digits = 15))
    post[v] <- if (nzchar(post[[v]])) paste(post[[v]], line, sep = "; ") else line
  }
  # mice() accepts EITHER predictorMatrix (calltype "pred") OR formulas
  # (calltype "formula") per call, never both: passing both breaks
  # make.calltype(). Replay whichever the baseline used. Verified against
  # mice 3.x: each branch reproduces $imp exactly under the same seed.
  spec <- if (any(mids$calltype == "formula")) {
    list(formulas = mids$formulas)
  } else {
    list(predictorMatrix = mids$predictorMatrix)
  }
  do.call(mice::mice, c(
    list(
      mids$data,
      m = mids$m, maxit = mids$iteration, method = mids$method,
      blocks = mids$blocks, visitSequence = mids$visitSequence,
      where = mids$where, blots = mids$blots, ignore = mids$ignore,
      post = post, seed = seed, printFlag = FALSE
    ),
    spec
  ))
}

# Realized MARGINAL sensitivity parameter: mean(imputed) - mean(observed) for
# the target, averaged over imputations. This is what the user probably thought
# `delta` was; reporting it exposes the CSP/MSP gap instead of hiding it.
.mnar_realized_msp <- function(imp, target) {
  obs <- imp$data[[target]]
  obs_mean <- mean(obs[!is.na(obs)])
  imp_cells <- imp$imp[[target]]
  if (is.null(imp_cells) || !length(imp_cells)) {
    return(NA_real_)
  }
  mean(vapply(seq_len(ncol(imp_cells)), function(k) {
    mean(as.numeric(imp_cells[[k]]))
  }, numeric(1))) - obs_mean
}
