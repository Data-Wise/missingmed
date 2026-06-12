#' Summary Method for SemImputedData Objects
#'
#' Provides a comprehensive summary of an SemImputedData object, including the SEM method used,
#' the number of imputations, basic information about the imputed data, and summaries of the
#' original data and fitted model.
#'
#' @param object An object of class SemImputedData.
#' @param ... Further arguments passed to or from other methods.
#' @return A textual summary of the SemImputedData object.
#' @importFrom mice convergence
#' @export
#' @examples
#' \dontrun{
#' # Assuming `sem_imputed_data` is an SemImputedData object
#' summary(sem_imputed_data)
#' }
setMethod("summary", "SemImputedData", function(object, ...) {
  cat("Summary of SemImputedData Object\n")
  cat("--------------------------------\n")

  # Display the SEM method used
  cat("SEM Method Used:", object@method, "\n\n")

  # Display the number of imputations
  cat("Number of Imputations:", object@n_imputations, "\n\n")

  # Summary of the original data
  if (!is.null(object@original_data)) {
    cat("Original Data Summary:\n")
    print(summary(object@original_data))
    cat("\n")
  } else {
    cat("Original data not available.\n\n")
  }

  # Summary of the fitted model (if applicable)
  if (!is.null(object@fit_model)) {
    cat("Fitted Model Summary:\n")
    print(summary(object@fit_model))
    cat("\n")
  } else {
    cat("Fitted model not available.\n\n")
  }

  # Summary of the 'data' slot of the 'mids' object
 if (!is.null(object@data)) {
    cat("Imputed Data Summary ('data' slot of 'mids' object):\n")
    print(object@data)
    cat("\n")
  } else {
    cat("Imputed data ('data' slot of 'mids' object) not available.\n\n")
  }
  invisible(object)
})

### =================================================================================================
### Summary Method for MediationCI Objects
### =================================================================================================


# NOTE: the dead S4 summary method for the non-existent 'MediationCI' class was
# removed during the S7 migration (Phase 0). Indirect-effect summaries now live
# on RMediation's CI objects (see infer()).
