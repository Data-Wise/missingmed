#' @keywords internal
#'
#' @description
#' missingmed runs regression-based mediation analysis across multiply imputed datasets
#' and pools with Rubin's rules. It is a thin orchestration layer: it **fits**
#' each imputation with [medfit] and delegates **inference** to [RMediation].
#'
#' @section S7 pipeline:
#' \itemize{
#'   \item [set_md_mediation()] -> [MDMediationData]: imputed data + mediation spec
#'   \item [run()] -> [MDMediationFit]: a list of named [medfit::MediationData], one per imputation
#'   \item [pool()] -> [MDMediationResult]: Rubin's-rules pooled named [medfit::MediationData]
#'   \item [infer()]: indirect-effect CI ([RMediation::ci_mediation_data()]) or D4-stacked MBCO
#'   \item [per_imputation_list()]: per-imputation fits for MBCO (which does not commute with Rubin's rules)
#' }
#'
#' @section Removed S4 API:
#' The S4 functions `set_sem()`, `run_sem()`, `pool_sem()`, `fit_model()`,
#' `lav_mice()` and `mx_mice()` were deprecated in 0.5.0, turned into
#' `.Defunct()` stubs in 0.6.0 and removed in 0.7.0. See
#' `vignette("s4-migration", package = "missingmed")` for the replacements.
#'
#' @author Davood Tofighi \email{dtofighi@@gmail.com}
#'
#' @importFrom stats coef var vcov
#' @importFrom rlang %||%
#' @importFrom tibble as_tibble
#' @importFrom methods is
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
