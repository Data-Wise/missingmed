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
#' Rezvan et al. 2018). How the delta enters depends on the target's imputation
#' method:
#'
#' * `"norm"`: delegated to `mice`'s NARFCS method `mnar.norm` (Tompsett et al.
#'   2018; Moreno-Betancur, van Buuren & White 2020), delta in raw units. For a
#'   constant delta this gives exactly the same draws as shifting them.
#' * `"logreg"` (a binary target): delegated to `mnar.logreg`, which offsets
#'   the imputation model's linear predictor -- delta on the **log-odds** scale.
#' * anything else continuous (`pmm`, `norm.nob`, `cart`, ...): the drawn values
#'   are shifted through `mice`'s `post` argument, delta in raw units.
#'
#' Each rung re-imputes from the `mids` object's stored settings --
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
#' * Categorical targets: binary via `logreg` only. Multinomial and ordinal
#'   targets (`polyreg`, `polr`, `lda`) are refused -- `mice` has no NARFCS
#'   method for them -- and so is `logreg.boot`, which has no counterpart.
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
                             level = NULL, n.mc = 1e5, ...) {
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

  # Every route enters only inside the sampler: `post` runs per iteration, and
  # mnar.norm/mnar.logreg leave the fill-in draws unshifted too (verified,
  # mice 3.19.0). A maxit = 0 baseline (the standard "set up, then edit" idiom) has
  # fill-in draws but no chain, so every rung would silently return the
  # unshifted imputation and the sensitivity curve would be flat.
  if (isTRUE(mids$iteration == 0)) {
    stop("The supplied `mids` was built with maxit = 0, so there is no ",
      "imputation chain for the delta to enter and every rung would be ",
      "identical. Re-impute with maxit >= 1.",
      call. = FALSE
    )
  }

  level <- level %||% object@conf_level

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

  meth <- unname(mids$method[vapply(targets, .mnar_block_of, character(1), mids = mids)])
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
    type = type, level = level, seed = seed, seed_source = seed_source,
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
    # `mids$method` is keyed by BLOCK, not by variable: a univariate block with
    # a non-default name gives method[v] = NA for a perfectly valid target, and
    # a multivariate block named after one of its members gives a hit for an
    # invalid one. Ask the blocks themselves.
    blk <- .mnar_block_of(mids, v)
    if (length(mids$blocks[[blk]]) > 1L) {
      stop("Target '", v, "' sits in the multivariate block '", blk, "' (",
        paste(mids$blocks[[blk]], collapse = ", "), "). Delta adjustment needs ",
        "a per-variable imputation method.",
        call. = FALSE
      )
    }
    if (!isTRUE(mids$nmis[[v]] > 0)) {
      stop("Target '", v, "' has no missing values, so a delta on it would do ",
        "nothing. Check the target name.",
        call. = FALSE
      )
    }
    # A binary target imputed by exactly "logreg" is delegated to mnar.logreg,
    # which offsets the linear predictor (delta on the log-odds scale). Every
    # other categorical case stays refused: an additive shift on drawn category
    # values is not meaningful, and mice ships no NARFCS method for them.
    meth <- unname(mids$method[[blk]])
    categorical <- is.factor(d[[v]]) || is.logical(d[[v]]) ||
      is.character(d[[v]]) || meth %in% c("logreg", "logreg.boot", "polyreg", "polr", "lda")
    if (categorical && !identical(meth, "logreg")) {
      if (identical(meth, "logreg.boot")) {
        stop("Target '", v, "' is imputed by 'logreg.boot', which has no NARFCS ",
          "counterpart; swapping it for mnar.logreg would change the imputation ",
          "method, so delta = 0 would no longer reproduce MAR. Re-impute with ",
          "method = 'logreg'.",
          call. = FALSE
        )
      }
      stop("Target '", v, "' is categorical and imputed by '", meth, "'. An ",
        "additive shift on drawn category values is not meaningful, and mice ",
        "has no NARFCS method for multinomial or ordinal targets. Supported: a ",
        "continuous target, or a binary target imputed by 'logreg' (delta on ",
        "the log-odds scale).",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

# Which mechanism applies the delta to target `v`? Only an EXACT method match
# is delegated to mice's NARFCS method: routing norm.nob/norm.boot/logreg.boot
# to mnar.* would change the imputation method itself, and delta = 0 would stop
# reproducing MAR. For a constant delta on a norm target the two mechanisms give
# identical draws (the spec's verified finding), so delegation there is a
# capability extension, not a correctness fix.
.mnar_route <- function(mids, v) {
  switch(unname(mids$method[[.mnar_block_of(mids, v)]]),
    norm = "mnar.norm",
    logreg = "mnar.logreg",
    "post"
  )
}

# A delta as a NARFCS `ums` string. Never scientific notation: parse.ums()
# reads "1e-05" as two intercept terms and errors.
.mnar_ums <- function(x) format(x, digits = 15, scientific = FALSE)

# Re-impute from the mids object's STORED SETTINGS (never mids$call, which
# references the caller's local symbols). A post-routed delta is composed into
# any post expression the user already had; an mnar-routed one swaps the
# block's method and merges `ums` into the block's blots -- never both, which
# would shift twice. mice keys `method` and `blots` by BLOCK, `post` by variable.
.mnar_reimpute <- function(mids, row, seed) {
  post <- mids$post
  method <- mids$method
  blots <- mids$blots
  for (v in names(row)) {
    route <- .mnar_route(mids, v)
    if (route == "post") {
      line <- sprintf("imp[[j]][, i] <- imp[[j]][, i] + (%s)", format(row[[v]], digits = 15))
      post[v] <- if (nzchar(post[[v]])) paste(post[[v]], line, sep = "; ") else line
    } else {
      blk <- .mnar_block_of(mids, v)
      method[[blk]] <- route
      blots[[blk]] <- utils::modifyList(
        as.list(blots[[blk]]), list(ums = .mnar_ums(row[[v]]))
      )
    }
  }
  # Replay the spec the baseline actually used. A pred-mode mids also stores an
  # auto-generated `formulas`, and handing mice() both that and the
  # predictorMatrix errors inside make.calltype(); so pass exactly one. Each
  # branch was verified against mice 3.19 to reproduce $imp bit-for-bit under
  # the same seed. `calltype` exists from mice 3.18.0 (see DESCRIPTION floor).
  ct <- mids$calltype
  spec <- if (all(ct == "formula")) {
    list(formulas = mids$formulas)
  } else if (all(ct == "pred")) {
    list(predictorMatrix = mids$predictorMatrix)
  } else {
    stop("The imputation mixes `predictorMatrix` and `formulas` blocks ",
      "(mice `calltype` = ", paste(unique(ct), collapse = "/"), "). ",
      "Delta adjustment cannot replay a mixed specification; impute with one ",
      "or the other.",
      call. = FALSE
    )
  }
  do.call(mice::mice, c(
    list(
      mids$data,
      m = mids$m, maxit = mids$iteration, method = method,
      blocks = mids$blocks, visitSequence = mids$visitSequence,
      where = mids$where, blots = blots, ignore = mids$ignore,
      post = post, seed = seed, printFlag = FALSE
    ),
    spec
  ))
}

# Realized MARGINAL sensitivity parameter: mean(imputed) - mean(observed) for
# the target, averaged over imputations. This is what the user probably thought
# `delta` was; reporting it exposes the CSP/MSP gap instead of hiding it.
# A binary FACTOR target is scored 0/1 (its second level = 1), so msp is then a
# prevalence difference on the probability scale -- as.numeric() on a factor
# would average level codes 1/2, and mean() of the observed factor is NA.
.mnar_realized_msp <- function(imp, target) {
  obs <- imp$data[[target]]
  score <- if (is.factor(obs)) {
    lev <- levels(obs)[2L]
    function(x) as.numeric(as.character(x) == lev)
  } else {
    as.numeric
  }
  obs_mean <- mean(score(obs[!is.na(obs)]))
  imp_cells <- imp$imp[[target]]
  if (is.null(imp_cells) || !length(imp_cells)) {
    return(NA_real_)
  }
  mean(vapply(seq_len(ncol(imp_cells)), function(k) {
    mean(score(imp_cells[[k]]))
  }, numeric(1))) - obs_mean
}

# Which mice block contains variable `v`? Blocks are named arbitrarily, so a
# name lookup on $method (keyed by block) is not a lookup on the variable.
.mnar_block_of <- function(mids, v) {
  hit <- vapply(mids$blocks, function(b) v %in% b, logical(1))
  if (!any(hit)) {
    stop("Target '", v, "' is not imputed by any block of this `mids`.",
      call. = FALSE
    )
  }
  names(mids$blocks)[which(hit)[1L]]
}
