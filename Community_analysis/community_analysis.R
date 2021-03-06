#LIBRARIES
library(deSolve)
library(dplyr)
library(FME)
library(reshape)
library(ggplot2)
library(foreach)
library(doParallel)
library(openxlsx)
library(DEoptim)
library(gridExtra)
library(kableExtra)
library(lmerTest)
library(psycho)
library(ggeffects)
library(rcompanion)
library(vegan)
library(stringr)
library(minpack.lm)
###############################################################################################
#GGPLOT THEME
theme_min<-theme(axis.text.x=element_text(vjust=0.2, size=18, colour="black"),
                 axis.text.y=element_text(hjust=0.2, size=18, colour="black"),
                 axis.title=element_text(size=18, colour="black"),
                 axis.line=element_line(size=0.5, colour="black"),
                 strip.text=element_text(size=18, face="bold"),
                 axis.ticks=element_line(size=1, colour="black"),
                 axis.ticks.length=unit(-0.05, "cm"),
                 panel.background=element_rect(colour="black", fill="white"),
                 panel.grid=element_line(linetype=0),
                 legend.text=element_text(size=14, colour="black"),
                 legend.title=element_text(size=14, colour="black"),
                 legend.position=c("right"),
                 legend.key.size=unit(1, "cm"),
                 strip.background=element_rect(fill="grey98", colour="black"),
                 legend.key=element_rect(fill="white", size=1.2),
                 legend.spacing=unit(0.5, "cm"),
                 plot.title=element_text(size=18, face="bold", hjust=-0.05))
###############################################################################################
#Cell size
size<-read.xlsx(xlsxFile = c("/home/petacapek/Dokumenty/pracovni/data_statistika/minT/Mint_CSub3_cellsort_size_dnaRFU.xlsx"),
                2)
summary(size)
#Broth
mean(c(size$B1, size$B2, size$B3, size$B4), na.rm=T)
#Mixed glass
mean(c(size$MG0, size$MG1, size$MG2, size$MG3, size$MG4), na.rm=T)
#Glass wool
mean(c(size$GW0, size$GW1, size$GW2, size$GW3, size$GW4), na.rm=T)

hist(c(size$B1, size$B2, size$B3, size$B4))
hist(c(size$MG0, size$MG1, size$MG2, size$MG3, size$MG4))
hist(c(size$GW0, size$GW1, size$GW2, size$GW3, size$GW4))

dsize<-data.frame(size=c(size$B1, size$B2, size$B3, size$B4,
                         size$MG0, size$MG1, size$MG2, size$MG3, size$MG4,
                         size$GW0, size$GW1, size$GW2, size$GW3, size$GW4),
                  Structure = c(rep("BROTH", times=length(c(size$B1, size$B2, size$B3, size$B4))),
                                rep("GLASS", times=length(c(size$MG0, size$MG1, size$MG2, size$MG3, size$MG4))),
                                rep("WOOL", times=length(c(size$GW0, size$GW1, size$GW2, size$GW3, size$GW4)))))

ggplot(dsize, aes(x=size)) + geom_histogram(aes(fill=Structure), alpha=0.5,
                                            position = position_dodge())
###############################################################################################
#DATA
##respiration rates in umol/ml/h
resp<-read.csv(file=c("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/data_checked_respiration_raw.csv"))

##arrange the data
resp.ordered<-resp[order(resp$Sample, resp$Day), ]

##biological data
biology<-read.csv(file=c("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/data_checked_biology_raw.csv"))

##arrange the data in the same way
biology.ordered<-biology[order(biology$Sample, biology$Day), -c(2,3)]
biology.ordered$Sample<-paste0("CSub3_", biology.ordered$Sample)

##merging both data sets
m0<-merge(resp.ordered, biology.ordered, by.x=c("Sample", "Day"), by.y = c("Sample", "Day"), all=T)

##removing rows with NA
m0<-m0[!is.na(m0$Time), ]

##recalculating ptoteins and DNA concentration to umol C - basis
m0$Protinc<-m0$Prot.in*0.46/12.01/4
m0$Protoutc<-m0$Prot.out*0.46/12.01/4
m0$DNAc<-m0$DNA*0.51/12.01/4
m0$DNA.initc<-m0$DNA.init*0.51/12.01/4

##Figures
m0 %>% filter(Substrate=="Celluloze" | Substrate=="Mix") %>% 
  group_by(Day, Structure, Substrate) %>%
  summarize(y=mean(Protinc, na.rm=T),
            y.sd=sd(Protinc, na.rm=T)) %>%
  ggplot(aes(Day, y))+geom_point(cex=6, pch=21, aes(fill=Structure))+
  geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  theme_min+facet_wrap(~Substrate, scales="free")

m0 %>% filter(Substrate!="Free") %>% 
  group_by(Day, Structure, Substrate) %>%
  summarize(y=mean(Protoutc, na.rm=T),
            y.sd=sd(Protoutc, na.rm=T)) %>%
  ggplot(aes(Day, y))+geom_point(cex=6, pch=21, aes(fill=Structure))+
  geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  theme_min+facet_grid(~Substrate)

m0 %>% filter(Substrate=="Celluloze" | Substrate=="Mix") %>% 
  group_by(Day, Structure, Substrate) %>%
  summarize(y=mean(DNAc, na.rm=T),
            y.sd=sd(DNAc, na.rm=T)) %>%
  ggplot(aes(Day, y))+geom_point(cex=6, pch=21, aes(fill=Structure))+
  geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  theme_min+facet_wrap(~Substrate, scales="free")

##Bacteria
bac<-as.data.frame(read.csv(file=c("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/OTU_bacteria.txt"), header=T,
                            sep="\t"))
#bac.tax<-as.data.frame(read.csv(file=c("/home/petacapek/Dokumenty/pracovni/data_statistika/minT/MinT/Community_analysis/OTU_bacteria.txt"), header=T,
#                             sep="\t"))
bac.tax<-bac.tax[, c(1, 175)]
bac.tax$X.OTU.ID<-gsub("_","", bac.tax$X.OTU.ID)

#Add taxonomy to bac.norm dataset
bac.norm_tax<-bac
#Transform the dataset
bac.norm_taxt<-as.data.frame(t(bac.norm_tax))
taxlab<-character()
for(i in 1:nrow(bac.norm_taxt)){
  nd<-which(bac.tax$X.OTU.ID==rownames(bac.norm_taxt)[i])
  taxlab<-append(taxlab, as.character(bac.tax$taxonomy[nd]))
}

bac.norm_taxt$taxonomy<-taxlab

#How to extract kingdom
pattern<-"k__(.+?),"
regmatches(bac.norm_taxt$taxonomy[1], regexec(pattern, bac.norm_taxt$taxonomy[1]))[[1]][2]
kingdoms<-character()
for(i in 1:nrow(bac.norm_taxt)){
  kingdoms<-append(kingdoms, 
                   regmatches(bac.norm_taxt$taxonomy[i], regexec(pattern, bac.norm_taxt$taxonomy[i]))[[1]][2])
}
kingdoms[which(kingdoms=="?")]<-c("Unknown")
bac.norm_taxt$Kingdom<-kingdoms

#How to extract phylum
pattern<-"p__(.+?),"

phylum<-character()
for(i in 1:nrow(bac.norm_taxt)){
  phylum<-append(phylum, 
                   regmatches(bac.norm_taxt$taxonomy[i], regexec(pattern, bac.norm_taxt$taxonomy[i]))[[1]][2])
}
phylum[which(phylum=="?")]<-c("Unknown")
bac.norm_taxt$Phylum<-phylum

#How to extract class
pattern<-"c__(.+?),"

cs<-character()
for(i in 1:nrow(bac.norm_taxt)){
  cs<-append(cs, 
                 regmatches(bac.norm_taxt$taxonomy[i], regexec(pattern, bac.norm_taxt$taxonomy[i]))[[1]][2])
}
which(cs=="?")
cs[which(cs=="?")]<-c("Unknown")
bac.norm_taxt$Class<-cs

#How to extract o
pattern<-"o__(.+?),"

os<-character()
for(i in 1:nrow(bac.norm_taxt)){
  os<-append(os, 
             regmatches(bac.norm_taxt$taxonomy[i], regexec(pattern, bac.norm_taxt$taxonomy[i]))[[1]][2])
}
which(os=="?")
os[which(os=="?")]<-c("Unknown")
bac.norm_taxt$Order<-os

#How to extract f
pattern<-"f__(.+?),"

fs<-character()
for(i in 1:nrow(bac.norm_taxt)){
  fs<-append(fs, 
             regmatches(bac.norm_taxt$taxonomy[i], regexec(pattern, bac.norm_taxt$taxonomy[i]))[[1]][2])
}

fs[which(fs=="?")]<-c("Unknown")
bac.norm_taxt$Family<-fs


#How to extract genus
pattern<-"g__(.+?),"

gs<-character()
for(i in 1:nrow(bac.norm_taxt)){
  gs<-append(gs, 
             regmatches(bac.norm_taxt$taxonomy[i], regexec(pattern, bac.norm_taxt$taxonomy[i]))[[1]][2])
}
which(gs=="?")
gs[which(gs=="?")]<-c("Unknown")
bac.norm_taxt$Genus<-gs


#How to extract species
pattern<-"s__(.+?),"

ss<-character()
for(i in 1:nrow(bac.norm_taxt)){
  ss<-append(ss, 
             regmatches(bac.norm_taxt$taxonomy[i], regexec(pattern, bac.norm_taxt$taxonomy[i]))[[1]][2])
}
which(is.na(ss))
ss[which(is.na(ss))]<-c("Unknown")
bac.norm_taxt$Specie<-ss

#Plots
tax_env<-bac_env
btaxt<-bac.norm_taxt[, 1:71]
tax_env$IDs<-colnames(btaxt)

##Genus
btaxtg<-btaxt
btaxtg$Genus<-bac.norm_taxt$Genus

Btaxtg<-melt(btaxtg, id.vars = c("Genus"))
colnames(Btaxtg)<-c("Genus", "IDs","Abundance")

Btaxtg<-merge(Btaxtg, tax_env, by.x = "IDs", by.y = "IDs", all.x = TRUE)
Btaxtg$Total<-numeric(length = nrow(Btaxtg))
for(i in unique(Btaxtg$IDs)){
  Btaxtg[Btaxtg$IDs==i, "Total"]<-sum(as.numeric(Btaxtg[Btaxtg$IDs==i, "Abundance"]))
}

bac_gen_f<-Btaxtg %>% group_by(Genus, Structure, Substrate) %>% 
  summarize(Abundance=mean(Abundance/Total, na.rm=T))


#Jen s abundanci nad 0.05
ggplot(bac_gen_f[bac_gen_f$Abundance>0.0005, ], aes(Structure, Genus)) +
  geom_tile(aes(fill = log10(Abundance*100))) +
  facet_grid(~ Substrate) +
  scale_fill_gradientn(colours = c("white","darkorange2","grey60"),
                       breaks = c(-2, -1, 0, 1, 2),
                       labels=c("0.01", "0.1", "0", "10", "100"),
                       name = "Relative abundance (%)",
                       guide = guide_colourbar(direction = "horizontal", title.position = "bottom",
                                               title.hjust = 0.5, barwidth = 12)) +
  scale_x_discrete(expand = c(0,0)) + #, labels = c("ctrl", "N")
  scale_y_discrete(expand = c(0,0)) + #limits = rev(levels(factor(prok_heat2$phylum))), 
  xlab("Structure") + ylab("")+
  coord_fixed(ratio=0.4) +
  theme_min + theme(legend.position = "bottom",
                    plot.margin = unit(c(0.01, 0, 0.01, 0), "in"))

bac_gen_f %>% filter(Genus=="Enterobacter") %>% group_by(Substrate, Structure) %>% 
  summarize(Abundance=mean(Abundance))
bac_gen_f %>% filter(Genus=="Pseudomonas") %>% group_by(Substrate, Structure) %>% 
  summarize(Abundance=mean(Abundance))
bac_gen_f %>% filter(Genus=="Burkholderia") %>% group_by(Substrate, Structure) %>% 
  summarize(Abundance=mean(Abundance))



##Fungi
f.tax<-as.data.frame(read.csv(file=c("/home/petacapek/Dokumenty/pracovni/data_statistika/minT/MinT/Community_analysis/OTU_fungi.txt"), header=T,
                             sep="\t"))
#Add taxonomy to fungi dataset
f.norm_tax<-fungi
#Transform the dataset
f.norm_taxt<-as.data.frame(t(f.norm_tax))
ftaxlab<-character()
for(i in 1:nrow(f.norm_taxt)){
  nd<-which(f.tax$X.OTU.ID==rownames(f.norm_taxt)[i])
  ftaxlab<-append(ftaxlab, as.character(f.tax$taxonomy[nd]))
}

f.norm_taxt$taxonomy<-ftaxlab

#How to extract kingdom
pattern<-"k__(.+?),"
regmatches(f.norm_taxt$taxonomy[1], regexec(pattern, f.norm_taxt$taxonomy[1]))[[1]][2]
kingdoms<-character()
for(i in 1:nrow(f.norm_taxt)){
  kingdoms<-append(kingdoms, 
                   regmatches(f.norm_taxt$taxonomy[i], regexec(pattern, f.norm_taxt$taxonomy[i]))[[1]][2])
}
kingdoms[which(kingdoms=="?")]<-c("Unknown")
f.norm_taxt$Kingdom<-kingdoms

#How to extract phylum
pattern<-"p__(.+?),"

phylum<-character()
for(i in 1:nrow(f.norm_taxt)){
  phylum<-append(phylum, 
                 regmatches(f.norm_taxt$taxonomy[i], regexec(pattern, f.norm_taxt$taxonomy[i]))[[1]][2])
}
phylum[which(phylum=="?")]<-c("Unknown")
f.norm_taxt$Phylum<-phylum

#How to extract class
pattern<-"c__(.+?),"

cs<-character()
for(i in 1:nrow(f.norm_taxt)){
  cs<-append(cs, 
             regmatches(f.norm_taxt$taxonomy[i], regexec(pattern, f.norm_taxt$taxonomy[i]))[[1]][2])
}
which(cs=="?")
cs[which(cs=="?")]<-c("Unknown")
f.norm_taxt$Class<-cs

#How to extract o
pattern<-"o__(.+?),"

os<-character()
for(i in 1:nrow(f.norm_taxt)){
  os<-append(os, 
             regmatches(f.norm_taxt$taxonomy[i], regexec(pattern, f.norm_taxt$taxonomy[i]))[[1]][2])
}
which(os=="?")
os[which(os=="?")]<-c("Unknown")
f.norm_taxt$Order<-os

#How to extract f
pattern<-"f__(.+?),"

fs<-character()
for(i in 1:nrow(f.norm_taxt)){
  fs<-append(fs, 
             regmatches(f.norm_taxt$taxonomy[i], regexec(pattern, f.norm_taxt$taxonomy[i]))[[1]][2])
}

fs[which(fs=="?")]<-c("Unknown")
f.norm_taxt$Family<-fs


#How to extract genus
pattern<-"g__(.+?),"

gs<-character()
for(i in 1:nrow(f.norm_taxt)){
  gs<-append(gs, 
             regmatches(f.norm_taxt$taxonomy[i], regexec(pattern, f.norm_taxt$taxonomy[i]))[[1]][2])
}
which(gs=="?")
gs[which(gs=="?")]<-c("Unknown")
f.norm_taxt$Genus<-gs


#How to extract species
pattern<-"s__(.+?),"

ss<-character()
for(i in 1:nrow(f.norm_taxt)){
  ss<-append(ss, 
             regmatches(f.norm_taxt$taxonomy[i], regexec(pattern, f.norm_taxt$taxonomy[i]))[[1]][2])
}
which(is.na(ss))
ss[which(is.na(ss))]<-c("Unknown")
f.norm_taxt$Specie<-ss

#Plots
ftax_env<-fungi_env
ftaxt<-f.norm_taxt[, 1:64]
ftax_env$IDs<-colnames(ftaxt)

##Genus
ftaxtg<-ftaxt
ftaxtg$Genus<-f.norm_taxt$Genus
ftaxtg$Order<-f.norm_taxt$Order

Ftaxtg<-melt(ftaxtg, id.vars = c("Genus", "Order"))
colnames(Ftaxtg)<-c("Genus", "Order","IDs","Abundance")

Ftaxtg<-merge(Ftaxtg, ftax_env, by.x = "IDs", by.y = "IDs", all.x = TRUE)
Ftaxtg$Total<-numeric(length = nrow(Ftaxtg))
for(i in unique(Ftaxtg$IDs)){
  Ftaxtg[Ftaxtg$IDs==i, "Total"]<-sum(as.numeric(Ftaxtg[Ftaxtg$IDs==i, "Abundance"]))
}

f_gen_f<-Ftaxtg %>% group_by(Genus, Order, Structure, Substrate) %>% 
  summarize(Abundance=mean(Abundance/Total, na.rm=T))


#Jen s abundanci nad 0.05%
ggplot(f_gen_f[f_gen_f$Abundance>0.0005, ], aes(Structure, Genus)) +
  geom_tile(aes(fill = log(Abundance*100))) +
  facet_grid(~ Substrate) +
  scale_fill_gradientn(colours = c("white","darkorange2","grey60"),
                       breaks = c(-2, -1, 0, 1, 2),
                       labels=c("0.01", "0.1", "0", "10", "100"),
                       name = "Relative abundance (%)",
                       guide = guide_colourbar(direction = "horizontal", title.position = "bottom",
                                               title.hjust = 0.5, barwidth = 12)) +
  scale_x_discrete(expand = c(0,0)) + #, labels = c("ctrl", "N")
  scale_y_discrete(expand = c(0,0)) + #limits = rev(levels(factor(prok_heat2$phylum))), 
  xlab("Structure") + ylab("")+
  coord_fixed(ratio=0.4) +
  theme_min + theme(legend.position = "bottom",
                    plot.margin = unit(c(0.01, 0, 0.01, 0), "in"))

unique(f_gen_f$Order)

f_gen_f %>% filter(Genus=="Gibberella") %>% group_by(Structure) %>% 
  summarize(Abundance=mean(Abundance))
f_gen_f %>% filter(Genus=="Verticillium") %>% group_by(Structure) %>% 
  summarize(Abundance=mean(Abundance, na.rm=T))

f_gen_f %>% filter(Order=="Saccharomycetales" |
                     Order=="Cystofilobasidiales" |
                     Order=="Sporidiobolales" |
                     Order=="Tremellales" |
                     Order=="Chaetothyriales") %>% group_by(Structure) %>% 
  summarize(Abundance=mean(Abundance*100, na.rm=T))


#############################################################################################
###without the taxonomy 
bacr<-bac[, -175]

###transpose and change colnames
bacr<-as.data.frame(t(bacr[, -1]))
colnames(bacr)<-as.character(bac[, 1])


###samples IDs and labels
bac_env<-rownames(bacr)
for(i in 1:length(bac_env)){
  bac_env[i]<-sub("[.]","_", sub("[.]","_", bac_env[i]))
}
rownames(bacr)<-bac_env
bac_env<-as.data.frame(bac_env)
colnames(bac_env)<-c("Sample")

biology.ordered$Sample<-str_sub(biology.ordered$Sample, 7, -1)
biology.ordered$Sample<-gsub("[W]", "", biology.ordered$Sample)
biology.ordered[substr(biology.ordered$Sample, 1, 2)=="MG", "Sample"]<-paste0(substr(biology.ordered[substr(biology.ordered$Sample, 1, 2)=="MG", "Sample"], 1, 1),
                                                    str_sub(biology.ordered[substr(biology.ordered$Sample, 1, 2)=="MG", "Sample"], 3, -1))

m0$Sample<-str_sub(m0$Sample, 7, -1)
m0$Sample<-gsub("[W]", "", m0$Sample)
m0[substr(m0$Sample, 1, 2)=="MG", "Sample"]<-paste0(substr(m0[substr(m0$Sample, 1, 2)=="MG", "Sample"], 1, 1),
                                                                              str_sub(m0[substr(m0$Sample, 1, 2)=="MG", "Sample"], 3, -1))


biology.ordered<-merge(biology.ordered, m0[, c("Sample", "Day", "Structure", "Substrate", "Time")],
                       by=c("Sample", "Day"), all.y = F)

bac_env$Day<-numeric(length = nrow(bac_env))
bac_env$Substrate<-character(length = nrow(bac_env))
bac_env$Structure<-character(length = nrow(bac_env))
bac_env$Time<-numeric(length = nrow(bac_env))

for(i in 1:nrow(bac_env)){
  tryCatch({
    bac_env[i, "Day"]<-as.numeric(biology.ordered[biology.ordered$Sample==bac_env$Sample[i], "Day"])
    bac_env[i, "Substrate"]<-as.character(biology.ordered[biology.ordered$Sample==bac_env$Sample[i], "Substrate"])
    bac_env[i, "Structure"]<-as.character(biology.ordered[biology.ordered$Sample==bac_env$Sample[i], "Structure"])
    bac_env[i, "Time"]<-as.numeric(biology.ordered[biology.ordered$Sample==bac_env$Sample[i], "Time"])
  }, error = function(e){print("Not found")})
  
}

###Initial community structure
bacr_i<-as.data.frame(bacr[substr(rownames(bacr),1,1)=="I", ])

###All community structure without initials and NAs
bacr$Time<-bac_env$Time

bac_env<-bac_env[bac_env$Time>0, ]
bacr_f<-bacr[bacr$Time>0, ]
bacr_f<-bacr_f[, -2134]

#Fungi
fung<-as.data.frame(read.csv(file=c("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/OTU_fungi.txt"), header=T,
                            sep="\t"))
###without the taxonomy 
fungr<-fung[, -170]

###transpose and change colnames
fungr<-as.data.frame(t(fungr[, -1]))
colnames(fungr)<-as.character(fung[, 1])


###samples IDs and labels
fun_env<-rownames(fungr)
for(i in 1:length(fun_env)){
  fun_env[i]<-sub("[.]","_", sub("[.]","_", fun_env[i]))
}
rownames(fungr)<-fun_env
fun_env<-as.data.frame(fun_env)
colnames(fun_env)<-c("Sample")

fun_env$Day<-numeric(length = nrow(fun_env))
fun_env$Substrate<-character(length = nrow(fun_env))
fun_env$Structure<-character(length = nrow(fun_env))
fun_env$Time<-numeric(length = nrow(fun_env))

for(i in 1:nrow(fun_env)){
  tryCatch({
    fun_env[i, "Day"]<-as.numeric(biology.ordered[biology.ordered$Sample==fun_env$Sample[i], "Day"])
    fun_env[i, "Substrate"]<-as.character(biology.ordered[biology.ordered$Sample==fun_env$Sample[i], "Substrate"])
    fun_env[i, "Structure"]<-as.character(biology.ordered[biology.ordered$Sample==fun_env$Sample[i], "Structure"])
    fun_env[i, "Time"]<-as.numeric(biology.ordered[biology.ordered$Sample==fun_env$Sample[i], "Time"])
  }, error = function(e){print("Not found")})
  
}

###Initial community structure
fungr_i<-as.data.frame(fungr[substr(rownames(fungr),1,1)=="I", ])

###All community structure without initials and NAs
fungr$Time<-fun_env$Time

fun_env<-fun_env[fun_env$Time>0, ]
fungr_f<-fungr[fungr$Time>0, ]
fungr_f<-fungr_f[, -625]

#Statistical analysis
##Does time significantly affect microbial community structure?
#Bacteria across all 
bac.norm<-decostand(bacr_f, method=c("total"))
bac.dist<-vegdist(bac.norm, method = "bray")
bac.ad<-adonis(bac.dist~Substrate+Structure/Substrate+Day, bac_env)

#For Celluloze only
bac.normC<-bac.norm[bac_env$Substrate=="Celluloze", ]
bac_envC<-bac_env[bac_env$Substrate=="Celluloze", ]

bac.distC<-vegdist(bac.normC, method = "bray")
bac.adC<-adonis(bac.distC~Structure+Day, bac_envC)

#Fungi across all 
fun.norm<-decostand(fungr_f, method=c("total"))
fun.dist<-vegdist(fun.norm, method = "bray")
fun.ad<-adonis(fun.dist~Substrate+Structure/Substrate+Day, fun_env)

#For Celluloze only
func.normC<-fun.norm[fun_env$Substrate=="Celluloze", ]
fun_envC<-fun_env[fun_env$Substrate=="Celluloze", ]

fun.distC<-vegdist(func.normC, method = "bray")
fun.adC<-adonis(fun.distC~Structure+Day, fun_envC)


##############################################################################################
#Celluloze - Mixed glass
##How the distances changes with the time

###Bacteria
####Subset the data
bacCB<-bacr_f[(bac_env$Substrate=="Celluloze" & bac_env$Structure=="Mixed glass"), ]
####Add initials
bacCB<-rbind(bacr_i, bacCB)
####Environmentals
bac_envCB<-bac_env[(bac_env$Substrate=="Celluloze" & bac_env$Structure=="Mixed glass"), 
                   c("Sample", "Time", "Day")]
####Add initials
bac_envCB<-rbind(data.frame(Sample=rep("I", 3),
                            Time=rep(0, 3),
                            Day=rep(0, 3)), bac_envCB)

####Remove zeros
z<-numeric()
for(i in 1:ncol(bacCB)){
  if(sum(bacCB[, i])>0){
    z<-append(z, i)
  }else{}
}
bacCB<-bacCB[, z]

bacCB.norm<-decostand(bacCB, method=c("total"))

####Distance matrix
#####Manual method
bac_envCB$D<-numeric(length = nrow(bac_envCB))
for(i in 1:nrow(bacCB.norm)){
  bac_envCB[i, "D"]<-sqrt(sum((bacCB.norm[i, ]-bacCB.norm[1, ]+
                                 bacCB.norm[i, ]-bacCB.norm[2, ]+
                                 bacCB.norm[i, ]-bacCB.norm[3, ])^2))
}

bac_envCB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(D),
            y.sd=sd(D)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  stat_function(fun=function(x){1.946*x/(80.642+x+x^2/31.159)})

summary(nlsLM(D~a*Time/(b+Time+Time^2/c), data=bac_envCB,
            start = list(a=0.5, b=10, c=0.2)))

####Scaling
bac_envCB$Dsc<-bac_envCB$D/bac_envCB$D[1:3]

bac_envCB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(Dsc),
            y.sd=sd(Dsc)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  stat_function(fun=function(x){4.221*x/(30.700+x+x^2/106.021)+1})

summary(nlsLM(Dsc~a*Time/(b+Time+Time^2/c)+1, data=bac_envCB,
              start = list(a=3, b=50, c=80)))
        
###Fungi
####Subset the data
funCB<-fungr_f[(fun_env$Substrate=="Celluloze" & fun_env$Structure=="Mixed glass"), ]
####Add initials
funCB<-rbind(fungr_i, funCB)
####Environmentals
fun_envCB<-fun_env[(fun_env$Substrate=="Celluloze" & fun_env$Structure=="Mixed glass"), 
                   c("Sample", "Time", "Day")]
####Add initials
fun_envCB<-rbind(data.frame(Sample=rep("I", 3),
                            Time=rep(0, 3),
                            Day=rep(0, 3)), fun_envCB)

####Remove zeros
z<-numeric()
for(i in 1:ncol(funCB)){
  if(sum(funCB[, i])>0){
    z<-append(z, i)
  }else{}
}
funCB<-funCB[, z]

funCB.norm<-decostand(funCB, method=c("total"))

####Distance matrix
#####Manual method
fun_envCB$D<-numeric(length = nrow(fun_envCB))
for(i in 1:nrow(funCB.norm)){
  fun_envCB[i, "D"]<-sqrt(sum((funCB.norm[i, ]-funCB.norm[1, ]+
                                 funCB.norm[i, ]-funCB.norm[2, ]+
                                 funCB.norm[i, ]-funCB.norm[3, ])^2))
}

fun_envCB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(D),
            y.sd=sd(D)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))

####Scaling
fun_envCB$Dsc<-fun_envCB$D/mean(fun_envCB$D[1:3])

fun_envCB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(Dsc),
            y.sd=sd(Dsc)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  geom_point(cex=6, data=bac_envCB, aes(Time, Dsc))

#####Modeling
m0CB<-subset(m0, Substrate=="Celluloze" & Structure=="Mixed glass")

ggplot(m0CB, aes(Time, r)) + geom_point(cex=6) + theme_min
ggplot(m0CB, aes(Time, Protinc)) + geom_point(cex=6) + theme_min
ggplot(m0CB, aes(Time, DNAc)) + geom_point(cex=6) + theme_min
ggplot(m0CB, aes(Time, Protoutc)) + geom_point(cex=6) + theme_min


####Round the time
m0CB$Time2<-round(m0CB$Time, 0)

####First all model parameters are constant
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/DB_constant.R")

out_const<-DB_constant(m0CB)
out_const$pars
out_const$fit$Gfit

ggplot(out_const$fit$Yhat, aes(time, obs))+geom_point(cex=6, pch=21, fill="grey")+
  facet_wrap(~variable, scales="free")+theme_min+
  geom_line(aes(time, yhat))

####Mr parameter vary with time depending on community structure

#####Linear relationship
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_lin.R")
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_lin_est.R")

Mr_lin_out<-Mr_lin_est(odeset=m0CB, par_const=out_const$pars)
Mr_lin_out$pars
Mr_lin_out$fit$Gfit

ggplot(Mr_lin_out$fit$Yhat, aes(time, obs))+geom_point(cex=6, pch=21, fill="grey")+
  facet_wrap(~variable, scales="free")+theme_min+
  geom_line(aes(time, yhat))

#####Exponential relationship
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_exp.R")
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_exp_est.R")

Mr_exp_out<-Mr_exp_est(odeset=m0CB, par_const=out_const$pars)
Mr_exp_out$pars
Mr_exp_out$fit$Gfit

ggplot(Mr_exp_out$fit$Yhat, aes(time, obs))+geom_point(cex=6, pch=21, fill="grey")+
  facet_wrap(~variable, scales="free")+theme_min+
  geom_line(aes(time, yhat))

#Mixed substrate - Broth
##How the distances changes with the time

###Bacteria
####Subset the data
bacMB<-bacr_f[(bac_env$Substrate=="Mix" & bac_env$Structure=="Broth"), ]
####Add initials
bacMB<-rbind(bacr_i, bacMB)
####Environmentals
bac_envMB<-bac_env[(bac_env$Substrate=="Mix" & bac_env$Structure=="Broth"), 
                   c("Sample", "Time", "Day")]
####Add initials
bac_envMB<-rbind(data.frame(Sample=rep("I", 3),
                            Time=rep(0, 3),
                            Day=rep(0, 3)), bac_envMB)

####Remove zeros
z<-numeric()
for(i in 1:ncol(bacMB)){
  if(sum(bacMB[, i])>0){
    z<-append(z, i)
  }else{}
}
bacMB<-bacMB[, z]

bacMB.norm<-decostand(bacMB, method=c("total"))

####Distance matrix
#####Manual method
bac_envMB$D<-numeric(length = nrow(bac_envMB))
for(i in 1:nrow(bacMB.norm)){
  bac_envMB[i, "D"]<-sqrt(sum((bacMB.norm[i, ]-bacMB.norm[1, ]+
                                 bacMB.norm[i, ]-bacMB.norm[2, ]+
                                 bacMB.norm[i, ]-bacMB.norm[3, ])^2))
}

bac_envMB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(D),
            y.sd=sd(D)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  stat_function(fun=function(x){1.946*x/(80.642+x+x^2/31.159)})

summary(nlsLM(D~a*Time/(b+Time+Time^2/c), data=bac_envMB,
              start = list(a=0.5, b=10, c=0.2)))

####Scaling
bac_envMB$Dsc<-bac_envMB$D/bac_envMB$D[1:3]

bac_envMB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(Dsc),
            y.sd=sd(Dsc)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))+
  geom_line(data=data.frame(timetest, y), aes(timetest, y))

timetest<-seq(0, 120)
y=ifelse(timetest<25, 1 + 0.66352*timetest, 17.6413*exp(-0.0025*timetest))

#Segmented function
sec_cost<-function(x){
  return(sum((bac_envMB$Dsc-ifelse(bac_envMB$Time<=x[1], 1 + x[2]*bac_envMB$Time,
         x[3]*exp(-x[4]*bac_envMB$Time)))^2))
}

sec_cost(c(0.3, 0.56, 15, 0.1))

DEoptim(fn=sec_cost, p = c(24, 0.6, 15, 0.002), lower = c(23, 0.01, 10, 0.0001),
        upper = c(26, 1, 20, 0.01),
        control = c(itermax = 10000, steptol = 50, reltol = 1e-8,
                    trace=FALSE, strategy=3, NP=250))

###Fungi
####Subset the data
funMB<-fungr_f[(fun_env$Substrate=="Mix" & fun_env$Structure=="Broth"), ]
####Add initials
funMB<-rbind(fungr_i, funMB)
####Environmentals
fun_envMB<-fun_env[(fun_env$Substrate=="Mix" & fun_env$Structure=="Broth"), 
                   c("Sample", "Time", "Day")]
####Add initials
fun_envMB<-rbind(data.frame(Sample=rep("I", 3),
                            Time=rep(0, 3),
                            Day=rep(0, 3)), fun_envMB)

####Remove zeros
z<-numeric()
for(i in 1:ncol(funMB)){
  if(sum(funMB[, i])>0){
    z<-append(z, i)
  }else{}
}
funMB<-funMB[, z]

funMB.norm<-decostand(funMB, method=c("total"))

####Distance matrix
#####Manual method
fun_envMB$D<-numeric(length = nrow(fun_envMB))
for(i in 1:nrow(funCB.norm)){
  fun_envMB[i, "D"]<-sqrt(sum((funMB.norm[i, ]-funMB.norm[1, ]+
                                 funMB.norm[i, ]-funMB.norm[2, ]+
                                 funMB.norm[i, ]-funMB.norm[3, ])^2))
}

fun_envMB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(D),
            y.sd=sd(D)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))

####Scaling
fun_envMB$Dsc<-fun_envMB$D/mean(fun_envMB$D[1:3])

fun_envMB %>% group_by(Day) %>%
  summarise(x=mean(Time),
            y=mean(Dsc),
            y.sd=sd(Dsc)) %>%
  ggplot(aes(x, y)) + geom_point(cex=6, pch=21, fill="grey")+
  theme_min+geom_errorbar(aes(ymin=y-y.sd, ymax=y+y.sd))

#####Modeling
m0MB<-subset(m0, Substrate=="Mix" & Structure=="Broth")

ggplot(m0MB, aes(Time, r)) + geom_point(cex=6) + theme_min
ggplot(m0MB, aes(Time, Protinc)) + geom_point(cex=6) + theme_min
ggplot(m0MB, aes(Time, DNAc)) + geom_point(cex=6) + theme_min
ggplot(m0MB, aes(Time, Protoutc)) + geom_point(cex=6) + theme_min

m0MB[(m0MB$Time>30 & m0MB$Time<75 & m0MB$Protoutc>0.6 & !is.na(m0MB$Protoutc)), "Protoutc"]<-NA

####Round the time
m0MB$Time2<-round(m0MB$Time, 0)

####First all model parameters are constant
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/DB_constantMB.R")

out_constMB<-DB_constantMB(m0MB)
out_constMB$pars
out_constMB$fit$Gfit

ggplot(out_constMB$fit$Yhat, aes(time, obs))+geom_point(cex=6, pch=21, fill="grey")+
  facet_wrap(~variable, scales="free")+theme_min+
  geom_line(aes(time, yhat))

####Mr parameter vary with time depending on community structure

#####Linear relationship
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_linMB.R")
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_lin_estMB.R")

Mr_lin_outMB<-Mr_lin_estMB(odeset=m0MB, par_const=out_constMB$pars)
Mr_lin_outMB$pars
Mr_lin_outMB$fit$Gfit

ggplot(Mr_lin_outMB$fit$Yhat, aes(time, obs))+geom_point(cex=6, pch=21, fill="grey")+
  facet_wrap(~variable, scales="free")+theme_min+
  geom_line(aes(time, yhat))

#####Exponential relationship
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_expDB.R")
source("C:/Users/cape159/Documents/pracovni/data_statistika/minT/MinT/Community_analysis/R_Functions/Models_linear/Mr_exp_estDB.R")

Mr_exp_outDB<-Mr_exp_estDB(odeset=m0MB, par_const=out_constMB$pars)
Mr_exp_outDB$pars
Mr_exp_outDB$fit$Gfit

ggplot(Mr_exp_outDB$fit$Yhat, aes(time, obs))+geom_point(cex=6, pch=21, fill="grey")+
  facet_wrap(~variable, scales="free")+theme_min+
  geom_line(aes(time, yhat))

