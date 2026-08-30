#' @keywords internal
#'
#' @description
#' missingmed runs SEM-based mediation analysis across multiply imputed datasets
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
#' @section Deprecated S4 API:
#' [set_sem()], [run_sem()], and [pool_sem()] are superseded by the S7 pipeline
#' above and kept for one release cycle.
#'
#' @author Davood Tofighi \email{dtofighi@@gmail.com}
#'
#' @importFrom stats coef var vcov
#' @importFrom rlang %||%
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
