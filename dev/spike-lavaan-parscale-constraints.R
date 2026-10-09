# Repro (2026-10-08): lavaan 0.7-2 returns converged fits that violate constraints under
# optim.parscale = "standardized"; 0.7-3 ignores parscale with a warning. See
# docs/reports/REPORT-lavaan-0.7-3-changes-2026-10-08.md

suppressMessages(library(lavaan)); set.seed(3); n<-300
X<-rnorm(n);M<-.3*X+rnorm(n);Y<-.3*M+.1*X+rnorm(n);d<-data.frame(X,M,Y); ds<-data.frame(X=X*50,M=M*50,Y=Y*50)
m<-"M~a*X\nY~b*M+cp*X"
chk<-function(lbl,mod,dat,...){ w<-NULL; r<-withCallingHandlers(try(sem(mod,dat,...),silent=TRUE),warning=function(x){w<<-c(w,substr(conditionMessage(x),1,70));invokeRestart("muffleWarning")})
 if(inherits(r,"try-error")) return(cat(sprintf("%-34s ERROR %s\n",lbl,substr(conditionMessage(attr(r,"condition")),1,80))))
 cf<-coef(r); cat(sprintf("%-34s conv=%s a=%.4f b=%.4f  a+b=%.4f a*b=%.4f %s\n",lbl,lavInspect(r,"converged"),cf["a"],cf["b"],cf["a"]+cf["b"],cf["a"]*cf["b"], if(length(w)) paste("WARN:",w[1]) else ""))}
chk("a+b==0.5 default",paste0(m,"\na+b==0.5"),d)
chk("a+b==0.5 parscale=standardized",paste0(m,"\na+b==0.5"),d,optim.parscale="standardized")
chk("a+b==0.5 scaled data x50, parscale",paste0(m,"\na+b==0.5"),ds,optim.parscale="standardized")
chk("a*b==0.05 parscale=standardized",paste0(m,"\na*b==0.05"),d,optim.parscale="standardized")
chk("a*b==0.05 scaled x50, parscale",paste0(m,"\na*b==0.05"),ds,optim.parscale="standardized")
chk("a==2*b parscale=standardized",paste0(m,"\na==2*b"),d,optim.parscale="standardized")
