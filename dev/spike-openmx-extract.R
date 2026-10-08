# Spike (2026-10-08): build a medfit::MediationData from an OpenMx fit and run RMediation MC CI.
# Shows an OpenMx extractor is feasible; MediationData needs raw data (data=) with nrow == n_obs.
# Needs OpenMx, medfit, RMediation. Expected indirect effect ~0.1962 (a*b = 0.4541*0.4320).
suppressMessages({library(OpenMx);library(medfit);library(RMediation)})
set.seed(1);n<-400;X<-rnorm(n);C<-rnorm(n);M<-.45*X+.3*C+rnorm(n);Y<-.4*M+.2*X+.3*C+rnorm(n);d<-data.frame(X,M,Y,C);ov<-names(d)
omx<-mxModel("p",type="RAM",manifestVars=ov,
 mxPath("X",to="M",values=0,labels="a"),mxPath("C",to="M",values=0,labels="mc"),mxPath("M",to="Y",values=0,labels="b"),
 mxPath("X",to="Y",values=0,labels="cp"),mxPath("C",to="Y",values=0,labels="yc"),
 mxPath(c("M","Y"),arrows=2,values=.5,labels=c("vm","vy")),mxPath(c("X","C"),arrows=2,values=1,labels=c("vx","vc")),mxPath("X",to="C",arrows=2,values=0,labels="cxc"),mxData(cov(d),type="cov",numObs=n))
r<-mxRun(omx,silent=TRUE,suppressWarnings=TRUE)
est<-coef(r); V<-vcov(r); cat("coef:",paste(names(est),collapse=","),"\nvcov dim",dim(V),"| nobs",r$data$numObs,"| status",r$output$status$code,"| SE a",sqrt(V["a","a"]),"\n")
ex<-setdiff(ls("package:medfit"),"")
cat("medfit generics w/ extract:",grep("extract",ex,value=TRUE),"\n")
# build MediationData by hand from OpenMx fit
al<-c(a="a",b="b",c_prime="cp"); est2<-c(est,a=unname(est["a"]),b=unname(est["b"]),c_prime=unname(est["cp"]))
V2<-matrix(0,length(est2),length(est2),dimnames=list(names(est2),names(est2))); V2[names(est),names(est)]<-V
for(k in names(al)){ V2[k,]<-0;V2[,k]<-0;src<-al[[k]]; V2[k,names(est)]<-V[src,];V2[names(est),k]<-V[,src];V2[k,k]<-V[src,src]}
md<-try(medfit::MediationData(a_path=unname(est["a"]),b_path=unname(est["b"]),c_prime=unname(est["cp"]),estimates=est2,vcov=V2,sigma_m=unname(sqrt(est["vm"])),sigma_y=unname(sqrt(est["vy"])),
   treatment="X",mediator="M",outcome="Y",data=d,n_obs=as.integer(r$data$numObs),converged=r$output$status$code==0,source_package="OpenMx"),silent=TRUE)
if(inherits(md,"try-error")) cat("MediationData ERROR:",conditionMessage(attr(md,"condition")),"\n") else {cat("MediationData built; source",md@source_package,"\n")
 ci<-try(RMediation::ci_mediation_data(md,type="MC",n_mc=1e5,seed=1),silent=TRUE); if(inherits(ci,"try-error")) cat("ci ERROR",conditionMessage(attr(ci,"condition")),"\n") else print(ci)}
