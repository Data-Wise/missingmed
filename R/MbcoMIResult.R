#' MbcoMIResult: D4-stacked MBCO test result (S7)
#'
#' The value of `infer(<MDMediationFit>, type = "mbco")` and [mbco_d4()]. It is
#' an S7 object whose parent is `class_double`: its data is the named numeric
#' vector `c(D4, p, r4, nu, d_S)`, and the properties carry how it was computed
#' and the branch diagnostics.
#'
#' * `D4`: the pooled statistic, referred to \eqn{F(k, \nu)}.
#' * `p`: its p-value.
#' * `r4`: the relative increase in variance, clamped at 0.
#' * `nu`: the denominator degrees of freedom (`Inf` when `r4` is 0).
#' * `d_S`: the MBCO statistic on the stacked data divided by the number of
#'   imputations.
#'
#' `x["p"]`, `x[["p"]]` and `is.numeric(x)` work as they did on the plain
#' vector returned by missingmed 0.4.0 and earlier, and `S7::S7_data(x)`
#' returns that vector. Two things differ: `identical(x, old_vector)` is
#' `FALSE`, and `x$p` is an error.
#'
#' @param .data Named numeric `c(D4, p, r4, nu, d_S)`.
#' @param ariv `"fixed"` or `"own"`: which per-imputation statistics fed `r4`
#'   (see [mbco_d4()]).
#' @param k Number of parameters the constraint removes (numerator df).
#' @param m Number of imputations pooled.
#' @param stacked_branch `"a"` or `"b"`: the branch (`a = 0` or `b = 0`) chosen
#'   by the constrained fit on the stacked data.
#' @param branch_mix Logical; `TRUE` when the imputations disagree on their own
#'   winning branch.
#' @param p_branch_a Share of imputations whose own winning branch is `a = 0`.
#' @return An `MbcoMIResult` S7 object.
#' @seealso [infer()], [mbco_d4()]
#' @examples
#' r <- MbcoMIResult(c(D4 = 4.7, p = 0.048, r4 = 1.16, nu = 13.8, d_S = 10.2),
#'   ariv = "fixed", k = 1, m = 5, stacked_branch = "b",
#'   branch_mix = TRUE, p_branch_a = 0.4
#' )
#' r[["p"]]
#' r@stacked_branch
#' @export
#' @name MbcoMIResult
MbcoMIResult <- S7::new_class(
  "MbcoMIResult",
  package = "missingmed",
  parent = S7::class_double,
  properties = list(
    ariv = S7::class_character,
    k = S7::class_numeric,
    m = S7::class_numeric,
    stacked_branch = S7::class_character,
    branch_mix = S7::class_logical,
    p_branch_a = S7::class_numeric
  ),
  validator = function(self) {
    if (!identical(names(S7::S7_data(self)), c("D4", "p", "r4", "nu", "d_S"))) {
      return("data must be a numeric vector named D4, p, r4, nu, d_S.")
    }
    if (length(self@ariv) != 1L || !self@ariv %in% c("fixed", "own")) {
      return("@ariv must be \"fixed\" or \"own\".")
    }
    if (length(self@k) != 1L || is.na(self@k) || self@k < 1) {
      return("@k must be a single positive number.")
    }
    if (length(self@m) != 1L || is.na(self@m) || self@m < 2) {
      return("@m must be a single number of imputations, at least 2.")
    }
    if (length(self@stacked_branch) != 1L || !self@stacked_branch %in% c("a", "b")) {
      return("@stacked_branch must be \"a\" or \"b\".")
    }
    if (length(self@branch_mix) != 1L || is.na(self@branch_mix)) {
      return("@branch_mix must be TRUE or FALSE.")
    }
    if (length(self@p_branch_a) != 1L || is.na(self@p_branch_a) ||
      self@p_branch_a < 0 || self@p_branch_a > 1) {
      return("@p_branch_a must be a single number in [0, 1].")
    }
    NULL
  }
)

# Not S4_register()ed, unlike the other classes: setOldClass() cannot build an
# S4 prototype for an S7 class whose parent is class_double, and nothing
# dispatches S4 methods on this result.

# S7 objects are not subsettable by default; index the underlying vector, so
# r["p"] and r[["p"]] return what they returned on the old plain vector. The
# functional form registers the methods without the `method<-` assignment
# copying `[` and `[[` into the namespace (where R CMD check sees them as
# undocumented exports).
S7::`method<-`(`[`, MbcoMIResult, value = function(x, i, ...) S7::S7_data(x)[i])
S7::`method<-`(`[[`, MbcoMIResult, value = function(x, i, ...) S7::S7_data(x)[[i]])
