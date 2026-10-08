#' Determine the Type of a SEM Model
#'
#' This internal function checks whether the provided model argument is
#' a valid "lavaan" syntax, a "lavaan" object, or an "MxModel" object from the
#' OpenMx package. It is used internally within the package to handle model
#' input flexibly.
#'
#' @param model The model to be checked. Can be a character string representing
#'   "lavaan" syntax, a "lavaan" object, or an "MxModel" object from the OpenMx
#'   package.
#'
#' @return A character string indicating the type of the model: "lavaan_syntax"
#'   for a valid "lavaan" syntax, "lavaan" for a "lavaan" object, or "MxModel"
#'   for an "MxModel" object.
#'
#' @examples
#' \dontrun{
#' # Assuming 'lavaan_model_syntax' is a character string with valid lavaan syntax
#' print(model_type(lavaan_model_syntax))
#'
#' # Assuming 'lavaan_obj' is a "lavaan" object created with the lavaan package
#' print(model_type(lavaan_obj))
#'
#' # Assuming 'mx_model_obj' is an "MxModel" object created with the OpenMx package
#' print(model_type(mx_model_obj))
#' }
#'
#' @keywords internal
#' @noRd
model_type <- function(model) {
    if (is.character(model)) {
        if (is_lav_syntax(model, quiet = TRUE)) {
            return("lavaan_syntax")
        } else {
            stop("The provided model syntax is not a valid 'lavaan' syntax. ",
                "Run is_lav_syntax(model) to see the parser error.",
                call. = FALSE)
        }
    } else if (inherits(model, "lavaan")) {
        return("lavaan")
    } else if (inherits(model, "MxModel")) {
        return(c("MxModel", "OpenMx"))
    } else {
        stop("Unsupported model of class '", class(model)[1], "'. ",
            "The model must be one of: a 'lavaan' model syntax string, ",
            "a 'lavaan' object, or an OpenMx 'MxModel' object.",
            call. = FALSE)
    }
}

### ----------------------------------------------------------------------------
### vcov_lav
### ----------------------------------------------------------------------------
#' Extract the sampling covariance matrix from a lavaan object
#' @param x A lavaan object
#' @return A matrix
#' @importFrom lavaan lavTech
#' @keywords internal
#' @noRd
vcov_lav <- function(x) {
    lavaan::lavTech(x, what = "vcov", add.labels = TRUE) # This is useful
}

### ----------------------------------------------------------------------------
### .fit_each_imputation
### ----------------------------------------------------------------------------
#' Fit one SEM per imputation with engine-aware error and warning handling
#'
#' Calls `fit_one(i)` for each imputation `i`. An error is rethrown naming the
#' engine and the imputation, keeping the engine's own message. Warnings are
#' collected and re-issued once, naming the affected imputations, so a
#' non-converged or improper solution in one imputation is not lost.
#' @param engine Engine label used in messages ("lavaan" or "OpenMx").
#' @param m Number of imputations.
#' @param fit_one A function of the imputation index returning a fitted model.
#' @return A list of length `m` of fitted models.
#' @keywords internal
#' @noRd
.fit_each_imputation <- function(engine, m, fit_one) {
    warn_imp <- integer(0)
    warn_msg <- character(0)
    fits <- lapply(seq_len(m), function(i) {
        withCallingHandlers(
            tryCatch(fit_one(i), error = function(e) {
                stop(engine, " failed on imputation ", i, ": ",
                    trimws(conditionMessage(e)),
                    call. = FALSE)
            }),
            warning = function(w) {
                warn_imp <<- c(warn_imp, i)
                warn_msg <<- c(warn_msg,
                    gsub("\\s+", " ", trimws(conditionMessage(w))))
                invokeRestart("muffleWarning")
            }
        )
    })
    if (length(warn_imp) > 0) {
        warning(engine, " issued warnings on imputation(s) ",
            paste(unique(warn_imp), collapse = ", "), " of ", m, ": ",
            paste(unique(warn_msg), collapse = "; "),
            call. = FALSE)
    }
    fits
}
