.libPaths(c(commandArgs(TRUE)[1], .libPaths())); suppressMessages({library(medfit); library(digest)})
cat("medfit", as.character(packageVersion("medfit")), " lavaan", as.character(packageVersion("lavaan")), "\n")
latent_pd <- "ind60 =~ x1 + x2 + x3\ndem60 =~ y1 + y2 + y3 + y4\ndem65 =~ y5 + y6 + y7 + y8\ndem60 ~ a*ind60\ndem65 ~ b*dem60 + cp*ind60"
latent_hs <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9\ntextual ~ a*visual\nspeed ~ b*textual + cp*visual"
obs <- function(x,m,y) sprintf("%s ~ a*%s\n%s ~ b*%s + cp*%s", m, x, y, m, x)
hs <- lavaan::HolzingerSwineford1939
data(jobs, package="mediation"); data(framing, package="mediation")
md <- tryCatch({ e <- new.env(); data("mediation_demo", package="medfit", envir=e); e$mediation_demo }, error=function(e) NULL)
cases <- list(
  list(id="PoliticalDemocracy", d=lavaan::PoliticalDemocracy, m=latent_pd, src="lavaan::PoliticalDemocracy (Bollen 1989)"),
  list(id="HS1939_all", d=hs, m=latent_hs, src="lavaan::HolzingerSwineford1939"),
  list(id="HS1939_Pasteur", d=hs[hs$school=="Pasteur",], m=latent_hs, src="HS1939 rows with school == Pasteur (existing column)"),
  list(id="HS1939_GrantWhite", d=hs[hs$school=="Grant-White",], m=latent_hs, src="HS1939 rows with school == Grant-White (existing column)"),
  list(id="jobs", d=data.frame(treat=as.numeric(jobs$treat), job_seek=jobs$job_seek, depress2=jobs$depress2), m=obs("treat","job_seek","depress2"), src="mediation::jobs (JOBS II)"),
  list(id="framing", d=data.frame(treat=as.numeric(framing$treat), emo=framing$emo, cong=as.numeric(framing$cong_mesg)), m=obs("treat","emo","cong"), src="mediation::framing")
)
if (!is.null(md) && all(c("treatment","mediator1","outcome") %in% names(md))) cases[[length(cases)+1]] <- list(id="medfit_mediation_demo", d=data.frame(treatment=as.numeric(md$treatment), mediator1=md$mediator1, outcome=md$outcome), m=obs("treatment","mediator1","outcome"), src="medfit::mediation_demo (treatment, mediator1, outcome)") else cat("mediation_demo: skipped\n")
hash_before <- vapply(cases, function(k) digest(k$d), "")
fitone <- function(model, d) {
  w <- character(); 
  r <- withCallingHandlers(tryCatch(fit_sem(model, d, fixed_x=FALSE, meanstructure=NULL), error=function(e) e),
    warning=function(x){ w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning")})
  if (inherits(r,"error")) return(list(ok=FALSE, msg=substr(conditionMessage(r),1,140), w=length(w)))
  g <- r@diagnostics
  list(ok=TRUE, f=r@f, status=format(g$status), improper=paste(g$improper, collapse="|"), bounds=paste(g$active_bounds, collapse="|"), w=length(w))
}
rows <- list()
for (k in cases) for (br in c("full","a","b")) {
  mod <- switch(br, full=k$m, a=paste(k$m,"a == 0",sep="\n"), b=paste(k$m,"b == 0",sep="\n"))
  r <- fitone(mod, k$d)
  rows[[length(rows)+1]] <- data.frame(case=k$id, n=nrow(k$d), branch=br, ok=r$ok, f=if (r$ok) round(r$f,5) else NA, status=if (r$ok) r$status else NA,
    improper=if (r$ok) r$improper else NA, bounds=if (r$ok) r$bounds else NA, warns=r$w, err=if (!r$ok) r$msg else "", stringsAsFactors=FALSE)
}
res <- do.call(rbind, rows); options(width=200); print(res[, c("case","n","branch","ok","f","status","improper","bounds","warns","err")], row.names=FALSE)
hash_after <- vapply(cases, function(k) digest(k$d), "")
cat("\ninput hashes unchanged:", identical(hash_before, hash_after), "\n")
for (i in seq_along(cases)) cat(sprintf("  %-22s %s  %s\n", cases[[i]]$id, substr(hash_before[i],1,12), cases[[i]]$src))
cand <- res[res$branch != "full" & ((res$ok & nzchar(res$improper)) | !res$ok), ]
cat("\nCANDIDATES (improper null or null-fit error):", nrow(cand), "\n"); if (nrow(cand)) print(cand[, c("case","branch","improper","err")], row.names=FALSE)
