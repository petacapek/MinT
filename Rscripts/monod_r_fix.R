###monod growth function
monod_r_fix<-function(data, FACT){
  
  #FACT 1 = Substrate, 2=Structure, 3=Both, 4=No
  
  if(FACT==1){
    
    dat<-data
    dat$id<-ifelse(data$Substrate=="Glucose", 1, 2)
    
  }else{
    
    if(FACT==2){
      
      dat<-data
      dat<-data
      ids<-dat %>% group_by(Structure) %>% summarise(id=n())
      ids$id<-seq(1:nrow(ids))
      
      dat<-merge(dat, ids, by.x=c("Structure"), by.y=c("Structure"))
      
    }else{
      
      if(FACT==3){
        
        dat<-data
        ids<-dat %>% group_by(Substrate, Structure) %>% summarise(id=n())
        ids$id<-seq(1:nrow(ids))
        
        dat<-merge(dat, ids, by.x=c("Substrate","Structure"), by.y=c("Substrate", "Structure"))
        
        
      }else{
        
        dat<-data
        dat$id<-c(1)
        
      }
    }
  }
  
  
  #monod growth function
  deriv<-function(time, state, pars){
    
    with(as.list(c(state, pars)),{
      
      dCmic<--k*Cmic+CUE*Vmax*Cmic*C/(Km+C)
      dC<-k*Cmic-Vmax*Cmic*C/(Km+C)
      
      return(list(c(dCmic, dC), r=(1-CUE)*Vmax*Cmic*C/(Km+C)))
      
    })
  }
  
  #define names of parameters
  parnames<-c("Vmax", "Km", "CUE", "k")
  
  #parameters estimation function
  estim<-function(odeset){
    
    #defining cost function
    cost<-function(x){
      
      par<-x[1:length(parnames)]
      
      names(par)<-parnames
      
      #first, pars dependent output from ode is matched with measured values
      yhat_all<-as.data.frame(ode(y=c(Cmic=0.1001656, C=25), parms=par, deriv, times=sort(odeset$Time)))
      
      #select time and the measured variables 
      yhat<-select(yhat_all, c("time", "r"))
      
      #add the measured data to a data frame
      yhat$obs<-c(odeset[order(odeset$Time), c("r")])
      
      #now, the root mean square error is calculated
      NRMSE<-as.numeric(yhat %>% summarise(NRMSE=sum(((r-obs)^2), na.rm = T)))
      
      return(NRMSE)
      
    }
    
    #defining goodness of fit function 
    rsq_ode<-function(x){
      
      par<-x[1:length(parnames)]
      
      names(par)<-parnames
      
      #first, pars dependent output from ode is matched with measured values
      yhat_all<-as.data.frame(ode(y=c(Cmic=0.1001656, C=25), parms=par, deriv, times=sort(odeset$Time)))
      
      #select time and the measured variables 
      yhat<-select(yhat_all, c("time", "r"))
      
      #add the measured data to a data frame
      yhat$obs<-c(odeset[order(odeset$Time), c("r")])
      yhat$Substrate<-odeset[order(odeset$Time), "Substrate"]
      yhat$Structure<-odeset[order(odeset$Time), "Structure"]
      
      #rsquared calculation for each variable
      Gfit<-yhat %>% summarise(SSres=sum(((obs-r)^2), na.rm = T),
                               SStot=sum(((obs-mean(obs, na.rm = T))^2), na.rm = T),
                               ll=-sum(((obs-r)^2), na.rm = T)/2/(sd(obs, na.rm = T)^2))
      Gfit$R2<-with(Gfit, 1-SSres/SStot)
      Gfit$N<-length(x)
      Gfit$AIC<-with(Gfit, 2*N-2*ll)
      
      rsq_out<-list(Yhat=yhat, Gfit=Gfit)
      
      return(rsq_out)
      
    }
    
    #approximate parameter estimation is done by MCMC method
    par_mcmc<-modMCMC(f=cost, p=c(Vmax=0.1, Km=3, CUE=0.5, k=1e-3), 
                      lower=c(Vmax=1e-6, Km=1e-3, CUE=0, k=1e-6),
                      upper=c(Vmax=10, Km=100, CUE=1, k=10), niter=10000)
    
    #lower and upper limits for parameters are extracted
    pl<-summary(par_mcmc)["min",]
    pu<-summary(par_mcmc)["max",]
    
    #these limits are used to find global optimum by DEoptim
    opt_par<-DEoptim(fn=cost, lower=pl, upper=pu, 
                     control = c(itermax = 10000, steptol = 50, reltol = 1e-8, 
                                 trace=FALSE, strategy=3, NP=250))
    
    #global optimum parameters are further used in MCMC to find parameters distribution
    par_prof<-modMCMC(f=cost, p=opt_par$optim$bestmem, 
                      lower=pl,
                      upper=pu, niter=5000)
    
    #goodness of fit
    fit<-rsq_ode(opt_par$optim$bestmem)
    
    #best parameters
    p<-opt_par$optim$bestmem
    names(p)<-parnames
    
    #return list with opt_par and par_prof
    estim_out<-list(pars=p, par_prof=par_prof, fit=fit)
    
    return(estim_out)
    
  }
  
  
  #parameter estimation
  if(FACT==4){
    
    res<-vector("list", length = 1)
    res[[1]]<-estim(odeset=dat)
    
  }else{
    
    res<-foreach(i=unique(dat$id), .combine=list, .multicombine = TRUE,
                 .packages=c("FME", "dplyr", "DEoptim", "reshape")) %dopar% {
                   
                   estim(odeset=dat[dat$id==i,])
                   
                 }
  }
  
  
  #calculation of overall goodness of fit from individual results
  if(FACT==4){
    
    res$goodness<-res[[1]]$fit$Gfit
    res$OvP<-res[[1]]$fit$Yhat
    
  }else{
    
    if(FACT==1){
      
      res$OvP<-rbind(res[[1]]$fit$Yhat, res[[2]]$fit$Yhat)
      
      #rsquared calculation for each variable
      res$goodness<-res$OvP %>% summarise(SSres=sum(((obs-r)^2), na.rm = T), 
                                          SStot=sum(((obs-mean(obs, na.rm = T))^2), na.rm = T),
                                          ll=-sum(((obs-r)^2), na.rm = T)/2/(sd(obs, na.rm = T)^2))
      res$goodness$R2<-with(res$goodness, 1-SSres/SStot)
      res$goodness$N<-length(parnames)*2+1
      res$goodness$AIC<-with(res$goodness, 2*N-2*ll)
      
      
    }else{
      
      if(FACT==2){
        
        res$OvP<-rbind(res[[1]]$fit$Yhat, res[[2]]$fit$Yhat, res[[3]]$fit$Yhat)
        
        #rsquared calculation for each variable
        res$goodness<-res$OvP %>% summarise(SSres=sum(((obs-r)^2), na.rm = T), 
                                            SStot=sum(((obs-mean(obs, na.rm = T))^2), na.rm = T),
                                            ll=-sum(((obs-r)^2), na.rm = T)/2/(sd(obs, na.rm = T)^2))
        res$goodness$R2<-with(res$goodness, 1-SSres/SStot)
        res$goodness$N<-length(parnames)*3+1
        res$goodness$AIC<-with(res$goodness, 2*N-2*ll)
        
      }else{
        
        res$OvP<-rbind(res[[1]]$fit$Yhat, res[[2]]$fit$Yhat, res[[3]]$fit$Yhat, res[[4]]$fit$Yhat, res[[5]]$fit$Yhat, res[[6]]$fit$Yhat)
        
        #rsquared calculation for each variable
        res$goodness<-res$OvP %>% summarise(SSres=sum(((obs-r)^2), na.rm = T), 
                                            SStot=sum(((obs-mean(obs, na.rm = T))^2), na.rm = T),
                                            ll=-sum(((obs-r)^2), na.rm = T)/2/(sd(obs, na.rm = T)^2))
        res$goodness$R2<-with(res$goodness, 1-SSres/SStot)
        res$goodness$N<-length(parnames)*6+1
        res$goodness$AIC<-with(res$goodness, 2*N-2*ll)
        
      }
    }
  }
  
  return(res)
}
