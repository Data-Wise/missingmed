#' @keywords internal
"_PACKAGE"

#' missingmed: Mediation Analysis with Multiple Imputation
#'
#' @description
#' The missingmed package provides S4 classes and methods for conducting
#' mediation analysis with multiply imputed datasets. It integrates with
#' the mice package for multiple imputation and supports structural equation
#' modeling using either lavaan or OpenMx.
#'
#' @section Main Classes:
#' \itemize{
#'   \item \code{\link{SemImputedData}}: Container for multiply imputed data and SEM model
#'   \item \code{\link{SemResults}}: Stores SEM results across imputations
#'   \item \code{\link{PooledSEMResults}}: Pooled estimates using Rubin's rules
#' }
#'
#' @section Main Functions:
#' \itemize{
#'   \item \code{\link{set_sem}}: Set up SEM analysis with imputed data
#'   \item \code{\link{run_sem}}: Run SEM on each imputed dataset
#'   \item \code{\link{pool_sem}}: Pool results across imputations
#' }
#'
#' @section Integration:
#' The package is designed to work seamlessly with RMediation for computing
#' confidence intervals of indirect effects in the presence of missing data.
#'
#' @author Davood Tofighi \email{dtofighi@@gmail.com}
#' @docType package
#' @name missingmed-package
NULL

## usethis namespace: start
## usethis namespace: end
