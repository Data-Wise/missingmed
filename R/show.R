#' @title Show SemImputedData
#'
#' @description Method to display a concise summary of a SemImputedData object.
#' This method is automatically called when you print a SemImputedData object.
#'
#' @param object The SemImputedData object to be displayed.
#' @return This method does not return a value but displays a summary of the SemImputedData object.
#' @export
#' @examples
#' \dontrun{
#' data("HolzingerSwineford1939", package = "lavaan")
#' hs_data <- HolzingerSwineford1939[paste0("x", 1:9)] |> mice::ampute()
#' hs_data <- hs_data$amp
#' imp_data <- mice::mice(HolzingerSwineford1939, m = 5)
#' model_lav <- "visual  =~ x1 + x2 + x3
#'              textual =~ x4 + x5 + x6
#'              speed   =~ x7 + x8 + x9"
#' imp_data <- mice::mice(hs_data, m = 5)
#' sem_data <- SemImputedData(imp_data, model_lav)
#' show(sem_data)
#' }
setMethod("show", "SemImputedData", function(object) {
  cat("Model Setup:\n")
  cat("Number of imputations:", object@n_imputations, "\n")
  cat("Confidence intervals included:", object@conf_int, "\n")
  cat("Confidence level:", object@conf_level, "\n")
  cat("Original data:\n", "Sample Size:", nrow(object@original_data),"\n")
  print(object@original_data[1:5,])
  cat("Method:", object@method, "\n")
  cat("Model:", object@model, "\n")
})


# NOTE: the dead S4 show method for the non-existent 'MediationCI' class was
# removed during the S7 migration (Phase 0).
