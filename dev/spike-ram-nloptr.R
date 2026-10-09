#!/usr/bin/env Rscript
# Spike (2026-10-08): native RAM engine + nloptr SLSQP vs lavaan. Exploratory; see
# docs/specs/PLAN-native-sem-engine-nloptr-2026-10-08.md. Needs lavaan, nloptr, numDeriv.
suppressMessages({library(lavaan);library(nloptr)})
# --- tiny RAM engine ---
mk <- function(vars, obs, paths, covs, fixed_cov = NULL){ # paths: list(to,from,lbl,val); covs same
  nv <- length(vars); ix <- function(v) match(v, vars)
  pr <- rbind(data.frame(m="A",r=ix(paths$to),c=ix(paths$from),lbl=paths$lbl,val=paths$val,stringsAsFactors=FALSE),
              data.frame(m="S",r=ix(covs$a),c=ix(covs$b),lbl=covs$lbl,val=covs$val,stringsAsFactors=FALSE))
  pr$free <- is.na(pr$val); pr$k <- NA; pr$k[pr$free] <- seq_len(sum(pr$free))
  list(vars=vars,obs=obs,nv=nv,pr=pr,F=diag(nv)[ix(obs),,drop=FALSE])}
mats <- function(mod,th){ A<-S<-matrix(0,mod$nv,mod$nv); for(i in seq_len(nrow(mod$pr))){p<-mod$pr[i,]; v<-if(p$free) th[p$k] else p$val
    if(p$m=="A") A[p$r,p$c]<-v else {S[p$r,p$c]<-v; S[p$c,p$r]<-v}}; list(A=A,S=S)}
sigma <- function(mod,th){m<-mats(mod,th);B<-solve(diag(mod$nv)-m$A);mod$F%*%B%*%m$S%*%t(B)%*%t(mod$F)}
fml <- function(mod,th,Sm){Sg<-sigma(mod,th);ev<-min(eigen(Sg,symmetric=TRUE,only.values=TRUE)$values);if(ev<=1e-10)return(1e10)
  log(det(Sg))+sum(diag(Sm%*%solve(Sg)))-log(det(Sm))-nrow(Sm)}
gml <- function(mod,th,Sm){m<-mats(mod,th);B<-solve(diag(mod$nv)-m$A);Sg<-mod$F%*%B%*%m$S%*%t(B)%*%t(mod$F);Si<-solve(Sg)
  W<-Si-Si%*%Sm%*%Si;P<-t(mod$F)%*%W%*%mod$F;gA<-2*t(B%*%m$S%*%t(B)%*%P%*%B);gS<-t(B)%*%P%*%B
  g<-numeric(length(th));for(i in seq_len(nrow(mod$pr))){p<-mod$pr[i,];if(!p$free)next
    g[p$k]<-g[p$k]+if(p$m=="A") gA[p$r,p$c] else if(p$r==p$c) gS[p$r,p$c] else 2*gS[p$r,p$c]};g}
fit <- function(mod,Sm,n,start,lb=NULL,eq=NULL,alg="NLOPT_LD_SLSQP"){
  q<-length(start); o<-nloptr(start,function(x)fml(mod,x,Sm),function(x)gml(mod,x,Sm),lb=if(is.null(lb))rep(-Inf,q) else lb,
    eval_g_eq=if(!is.null(eq))eq$g,eval_jac_g_eq=if(!is.null(eq))eq$j,opts=list(algorithm=alg,xtol_rel=1e-12,ftol_rel=1e-15,maxeval=2000))
  th<-o$solution; J<-sapply(seq_len(q),function(k){h<-1e-6;e<-replace(numeric(q),k,h);as.vector(sigma(mod,th+e)-sigma(mod,th-e))/(2*h)})
  Si<-solve(sigma(mod,th)); I<-(n/2)*t(J)%*%kronecker(Si,Si)%*%J; list(th=th,se=sqrt(diag(solve(I))),fmin=o$objective,status=o$status,iter=o$iterations)}
# --- data ---
set.seed(1);n<-400;X<-rnorm(n);C<-rnorm(n);M<-.45*X+.3*C+rnorm(n);Y<-.4*M+.2*X+.3*C+rnorm(n);d1<-data.frame(X,M,Y,C)
S1<-cov(d1[,c("X","M","Y","C")])*(n-1)/n
vars1<-c("X","C","M","Y")
mod1<-mk(vars1,c("X","M","Y","C"),
 list(to=c("M","M","Y","Y","Y"),from=c("X","C","M","X","C"),lbl=c("a","m_c","b","cp","y_c"),val=rep(NA,5)),
 list(a=c("X","C","C","M","Y"),b=c("X","C","X","M","Y"),lbl=c("vx","vc","cxc","vm","vy"),val=c(S1["X","X"],S1["C","C"],S1["X","C"],NA,NA)))
Sm1<-S1[c("X","M","Y","C"),c("X","M","Y","C")]
f1<-fit(mod1,Sm1,n,start=c(0,0,0,0,0,.5,.5))
lv<-sem("M~a*X+C\nY~b*M+cp*X+C",d1); pt<-parTable(lv); pe<-merge(pt[pt$free>0,c("id","lhs","op","rhs","free","est","se")],data.frame(),by=NULL)[0,]; pe<-pt[pt$free>0,]; pe$est<-pt$est[pt$free>0]; pe$se<-pt$se[pt$free>0]; pe<-pe[order(pe$free),]
cat("== observed path model (n=400) ==\n"); print(round(data.frame(own=f1$th,lav=pe$est,d_est=f1$th-pe$est,own_se=f1$se,lav_se=pe$se,d_se=f1$se-pe$se),7)); cat("status",f1$status,"iter",f1$iter,"\n")
# gradient check
th0<-c(.1,.2,.3,.1,.2,.8,.9);cat("grad check max|analytic-numeric|:",max(abs(gml(mod1,th0,Sm1)-numDeriv::grad(function(x)fml(mod1,x,Sm1),th0))),"\n")
# --- latent mediator ---
set.seed(2);n2<-300;X<-rnorm(n2);Mm<-.4*X+rnorm(n2);d2<-data.frame(X,m1=Mm+rnorm(n2,0,.5),m2=.8*Mm+rnorm(n2),m3=.7*Mm+rnorm(n2));d2$Y<-.4*Mm+.2*X+rnorm(n2)
S2<-cov(d2[,c("X","m1","m2","m3","Y")])*(n2-1)/n2
vars2<-c("X","M","m1","m2","m3","Y")
mod2<-mk(vars2,c("X","m1","m2","m3","Y"),
 list(to=c("m1","m2","m3","M","Y","Y"),from=c("M","M","M","X","M","X"),lbl=c("l1","l2","l3","g","b","cp"),val=c(1,NA,NA,NA,NA,NA)),
 list(a=c("X","m1","m2","m3","M","Y"),b=c("X","m1","m2","m3","M","Y"),lbl=c("vx","t1","t2","t3","vM","vY"),val=c(S2["X","X"],NA,NA,NA,NA,NA)))
Sm2<-S2
f2<-fit(mod2,Sm2,n2,start=c(1,1,0,0,0,.5,.5,.5,.5,.5))
lv2<-sem("M=~m1+m2+m3\nM~X\nY~M+X",d2); pt2<-parTable(lv2);pe2<-pt2[pt2$free>0,];pe2$key<-paste0(pe2$lhs,pe2$op,pe2$rhs);ok<-c("M=~m2","M=~m3","M~X","Y~M","Y~X","m1~~m1","m2~~m2","m3~~m3","M~~M","Y~~Y");pe2<-pe2[match(ok,pe2$key),]
cat("== latent mediator (n=300) ==\n");print(cbind(par=paste(pe2$lhs,pe2$op,pe2$rhs),round(data.frame(own=f2$th,lav=pe2$est,d_est=f2$th-pe2$est,d_se=f2$se-pe2$se),6)))
cat("max |d_est|",max(abs(f2$th-pe2$est)),"max |d_se|",max(abs(f2$se-pe2$se)),"\n")
# --- nonlinear constraint a*b==0 via SLSQP ---
eq<-list(g=function(x)x[1]*x[2],j=function(x)matrix(c(x[2],x[1],0,0,0),nrow=1))
set.seed(3);n3<-300;X<-rnorm(n3);M<-.3*X+rnorm(n3);Y<-.3*M+.1*X+rnorm(n3);d3<-data.frame(X,M,Y);S3<-cov(d3)*(n3-1)/n3
mod3<-mk(c("X","M","Y"),c("X","M","Y"),list(to=c("M","Y","Y"),from=c("X","M","X"),lbl=c("a","b","cp"),val=rep(NA,3)),
 list(a=c("X","M","Y"),b=c("X","M","Y"),lbl=c("vx","vm","vy"),val=c(S3[1,1],NA,NA)))
for(st in list(c(.3,.3,.1,1,1),c(.5,-.5,0,1,1),c(-.8,.8,.3,2,2),c(0,0,0,.5,.5))){
 g3<-try(fit(mod3,S3,n3,st,eq=eq),silent=TRUE)
 cat("a*b==0 start",st[1:2],"->",if(inherits(g3,"try-error"))"ERR" else sprintf("fmin=%.6f a=%.4f b=%.4f status=%d",g3$fmin,g3$th[1],g3$th[2],g3$status),"\n")}
cat("lavaan a*b==0 fmin 0.047577 (a==0), 0.053074 (b==0)\n")
