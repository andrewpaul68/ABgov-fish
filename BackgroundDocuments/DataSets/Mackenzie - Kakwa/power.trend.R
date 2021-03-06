# Estimate the power to detect a 10, 20, 50, 100, 200% increase in the abundance over 5 years
# This data has information on the within-year variation, but no information on process error.

# As usually, convert the estimates of variablity to the log-scale to answer the above questions.

library(ggplot2)
library(lme4)
library(lmerTest)
library(plyr)
library(reshape2)

# read in the data
cpue.moon <- read.csv("Moon.csv", header=TRUE, as.is=TRUE, strip.white=TRUE)
cpue.moon <- cpue.moon[ , c("System","Year","Site","BLTR_100m")]
cpue.moon <- cpue.moon[ !is.na(cpue.moon$BLTR_100m),]
cpue.moon <- cpue.moon[ !is.na(cpue.moon$Year),]
cpue.moon$Year      <- as.numeric(cpue.moon$Year)
cpue.moon$BLTR_100m <- as.numeric(cpue.moon$BLTR_100m)
cpue.moon$Type      <- "Backpack"
cpue.moon$Measure   <- "BLTR_100m"
cpue.moon <- plyr::rename(cpue.moon, replace=c("BLTR_100m"="value"))

cpue.mac <- read.csv("Mackenzie.csv", header=TRUE, as.is=TRUE, strip.white=TRUE)
cpue.mac <- cpue.mac[ , c("System","Year","Site","BLTR_100m")]
cpue.mac <- cpue.mac[ !is.na(cpue.mac$BLTR_100m),]
cpue.mac <- cpue.mac[ !is.na(cpue.mac$Year),]
cpue.mac$Year      <- as.numeric(cpue.mac$Year)
cpue.mac$BLTR_100m <- as.numeric(cpue.mac$BLTR_100m)
cpue.mac$Type      <- 'Backpack'
cpue.mac$Measure   <- "BLTR_100m"
cpue.mac <- plyr::rename(cpue.mac, replace=c("BLTR_100m"="value"))


cpue.kak <- read.csv("Kakwa-backpack.csv", header=TRUE, as.is=TRUE, strip.white=TRUE)
cpue.kak <- cpue.kak[ , c("System","Year","Site","BLTR_100m")]
cpue.kak <- cpue.kak[ !is.na(cpue.kak$BLTR_100m),]
cpue.kak <- cpue.kak[ !is.na(cpue.kak$Year),]
cpue.kak$Year      <- as.numeric(cpue.kak$Year)
cpue.kak$BLTR_100m <- as.numeric(cpue.kak$BLTR_100m)
cpue.kak$Type      <- 'Backpack'
cpue.kak$Measure   <- "BLTR_100m"
cpue.kak <- plyr::rename(cpue.kak, replace=c("BLTR_100m"="value"))

cpue.kakfb <- read.csv("Kakwa-float-boat.csv", header=TRUE, as.is=TRUE, strip.white=TRUE)
cpue.kakfb <- cpue.kakfb[ , c("System","Year","Site","BLTR_km")]
cpue.kakfb <- cpue.kakfb[ !is.na(cpue.kakfb$BLTR_km),]
cpue.kakfb <- cpue.kakfb[ !is.na(cpue.kakfb$Year),]
cpue.kakfb$Year      <- as.numeric(cpue.kakfb$Year)
cpue.kakfb$BLTR_km   <- as.numeric(cpue.kakfb$BLTR_km)
cpue.kakfb$Type      <- 'FloatBoat'
cpue.kakfb$Measure   <- "BLTR_km"
cpue.kakfb <- plyr::rename(cpue.kakfb, replace=c("BLTR_km"="value"))



head(cpue.moon)
head(cpue.mac)
head(cpue.kak)
head(cpue.kakfb)

cpue <- rbind(cpue.moon, cpue.mac, cpue.kak, cpue.kakfb)


xtabs(~interaction(System,Type, drop=TRUE)+Year, data=cpue, exclude=NULL, na.action=na.pass)


# Estimate sampling and process error by fitting trend lines to the three separate series
# we ignore sampling from the same site over time for now.
prelim <- ggplot(data=cpue, aes(x=Year, y=value))+
   ggtitle("Baseline data")+
   geom_point( position=position_jitter(w=.2))+
   geom_smooth(method="lm", se=FALSE)+
   facet_wrap(~interaction(System,Measure,Type,sep="   "), scales="free_y", ncol=1)
prelim
ggsave(plot=prelim, file='preliminary-plot.png', h=6, w=6, units="in", dpi=300)

prelim.log <- ggplot(data=cpue, aes(x=Year, y=log(value+.2)))+
  ggtitle("Baseline data - log scale")+
  geom_point( position=position_jitter(w=.2))+
  facet_wrap(~System, scales="free_y", ncol=1)+
  geom_smooth(method="lm", se=FALSE)+
  facet_wrap(~interaction(System,Measure,Type,sep="   "), scales="free_y", ncol=1)
prelim.log
ggsave(plot=prelim.log, file='preliminary-plot-log.png', h=6, w=6, units="in", dpi=300)


outliers <- cpue$System=='Kakwa' & cpue$Type=="FloatBoat" & cpue$Measure=="BLTR_km"  & (cpue$value > 2)  |
            cpue$System=='Kakwa' & cpue$Type=="FloatBoat" & cpue$Measure=="BLTR_km"  & (cpue$Year > 2005)
cpue[outliers,]

cpue <- cpue[ !outliers,]

# fit the model to the log to get the sampling and process error relative to the mean
range(cpue$value[cpue$value >0])

fits <- plyr::dlply(cpue, c("System","Measure","Type"), function(x){
   x$YearF <- factor(x$Year)
  
   fit <- lmerTest::lmer(log(value+.1) ~ Year + (1|YearF), data=x)
   print(summary(fit))
   list(System=x$System[1], 
        Measure=x$Measure[1],
        Type=x$Type[1],
        fit=fit)
})


vc <- ldply(fits, function (x){
   slopes <- summary(x$fit)$coefficients[2,c("Estimate","Std. Error","Pr(>|t|)")]
   vc <- as.data.frame(VarCorr(x$fit))
   data.frame(System =x$System,
              Type   =x$Type,
              Measure=x$Measure, 
              slope=slopes[1],
              slope.se=slopes[2],
              slope.p =slopes[3],
              SD.sampling=vc[2,"sdcor"], SD.process=vc[1,"sdcor"], stringsAsFactors=FALSE)
})
vc



temp <- vc
temp[, c(4:8)] <- round(temp[, c(4:8)],2)
temp

# now for power charts to detect 10%, 30%, 50%, 100%, 200%, 300% change over 5 years 
# by varying the number of sites at different levels of process error
source("../regression.power.R")


power.res <- ddply(vc, c("System","Type","Measure"), function (x, alpha=0.05){
  # set up the scenarios to estimate the power 
  #browser()
  scenarios <- expand.grid(PerChange=c(10, 30, 50, 100, 200),
                           Years=c(5,10),
                           Sampling.SD=x$SD.sampling,
                           Process.SD=x$SD.process,
                           sites.per.year=seq(20,100,10),
                           System=x$System,
                           Measure=x$Measure,
                           alpha=alpha)
  scenarios$Scenario <- 1:nrow(scenarios)
  # estimate the power to detect a trend for each scenario
  power <- plyr::ddply(scenarios, "Scenario", function(x){
      # estimate compounded trend line on the log scale
      Trend <-  (x$PerChange/100+1)^(1/(x$Years-1))-1
      # sampling every year
      Xvalues <- rep(1:x$Year, each=x$sites.per.year)
      res <- slr.power.stroup(Trend=Trend, 
                              Xvalues    =Xvalues   , 
                              Process.SD =x$Process.SD, 
                              Sampling.SD=x$Sampling.SD, 
                              alpha      =x$alpha)
      res <- cbind(res, x)
      res
   })
   # make a plot
   #browser()
   plotdata <- power
   plotdata$Years2 <- paste("Over ", plotdata$Year," Years",sep="")
   plotdata$PerChangeF <- factor(plotdata$PerChange)
   power.plot <- ggplot2::ggplot(data=plotdata, aes(x=sites.per.year, y=power.1sided.a, color=PerChangeF))+
      ggtitle(paste("Power to detect changes over time for ", x$System, " ",x$Type,"  ", x$Measure,"\n alpha=",power$alpha[1],
                    "; rProcess SD= ", format(round(power$Process.SD[1] ,2),nsmall=2), 
                    "; rSampling SD= ",format(round(power$Sampling.SD[1],2),nsmall=2), sep=""))+
      geom_line(aes(group=PerChangeF, linetype=PerChangeF))+
      ylab("Power")+ylim(0,1)+geom_hline(yintercept=0.80)+
      facet_wrap(~Years2, ncol=1, scales='fixed')+
      scale_color_discrete(name="Percent\nChange")+
      scale_linetype_discrete(name="Percent\nChange")
   plot(power.plot)
   ggsave(plot=power.plot, file=paste('power-',x$System,"-",x$Type,"-",x$Measure,"-rProcessSD-",
                                      format(round(power$Process.SD[1],2),nsmall=2),".png",sep=""),
           h=6, w=6, dpi=300)
   power
  }, alpha=.05)
head(power.res)




