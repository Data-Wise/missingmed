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
#' @section Defunct S4 API:
#' [set_sem()], [run_sem()] and [pool_sem()] were removed in 0.6.0 and now stop
#' with a message naming their replacement; see [missingmed-defunct].
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
