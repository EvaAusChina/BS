# setwd("/Users/qihua/Public/BS")
# source("mother_sample.R")
library(Matrix)
library(stringr)
library("data.table")
csv <- fread("phenotypes.both_sexes.tsv", header=TRUE, sep='\t', data.table=FALSE)
phenofile <-readRDS("20190901_R2.rds")
source("sojo.phenotype.function.R")

csvnn <- csv[csv[,3]=="binary",]
### remove illnesses of father and sibrings
csvdata <- csvnn[!(str_detect(csvnn[,2], "Illnesses")), c(1,5,6,7,8)]
ncase <- as.numeric(csvdata[,5])
ncontrol <- as.numeric(csvdata[,4])
nnnnn1 <- as.numeric(csvdata[,2])

##### obtain mean and var of binary data
nmean <- ncase / nnnnn1
nvar <- ncontrol * ncase / (nnnnn1 * nnnnn1)
csvdata[,6] <- nmean
csvdata[,7] <- nvar
colnames(csvdata)[6] <- "mean"
colnames(csvdata)[7] <- "var"
csvb <- csvdata[,c(1,6,7)]

##### obtain mean and var of continuous data
csvc_raw <- csv[csv[,3]=="continuous_irnt",]
len <- nrow(csvc_raw)
csvc_raw[,2] <- rep(0, len)
csvc_raw[,3] <- rep(1, len)
csvc <- csvc_raw[,c(1,2,3)]
colnames(csvc) <- colnames(csvb)
csvn1 <- rbind(csvb, csvc)
csvn2 <- csvn1[csvn1[,1] != "1807_irnt", ]
csvn <- csvn2[csvn2[,1] != "4501", ]
#csvn <- csvn3[csvn3[,1] != "2139_irnt", ]

##### seek overlap between correlation matrix and phenotype table
phenotype.overlap <- intersect(csvn$phenotype, colnames(phenofile))

##### obtain correlation matrix
LD_phenomat <- phenofile[phenotype.overlap, phenotype.overlap]

##### select summary statistics concerning with and without ""
informat <-  csvn[csvn$phenotype %in% phenotype.overlap,]
yinformat <- subset(informat, phenotype == "3526_irnt", select = c(phenotype, mean, var))
xinformat <-  subset(informat, phenotype != "3526_irnt", select = c(phenotype, mean, var))

##### obtain yxcorrelation and xxcorrelation
vec <- which(colnames(LD_phenomat)== "3526_irnt")
yxcor <- LD_phenomat[vec, -vec]
xxcor <- LD_phenomat[-vec, -vec]


##### gain selected markers and in sample r2
df.sojo <- data.frame(var.x = xinformat$var, cor.x.y = yxcor)

res <- sojo.phenotype(sum.stat.discovery = df.sojo, cor.X = xxcor, v.y = yinformat$var, nvar = 10)
sojo.insample  <- sojo.phenotype(sum.stat.discovery =df.sojo, sum.stat.validation = df.sojo,
                                 cor.X = xxcor, v.y = yinformat$var, v.y.validation = yinformat$var, nvar = 10)

##### obtain estimated beta 
vec <- which(colnames(LD_phenomat) == "3526_irnt")
cor.x.y <- LD_phenomat[vec, -vec]
cor.x <- LD_phenomat[-vec, -vec]
cov.x <- diag(sqrt(xinformat$var)) %*% cor.x %*% diag(sqrt(xinformat$var))
colnames(cov.x) <- colnames(cor.x)
row.names(cov.x) <- row.names(cor.x)
cov.x.y <- cor.x.y * sqrt(yinformat$var) * sqrt(xinformat$var)

cov.x <- cov.x[res$selected.markers,res$selected.markers]
cov.x.y <- cov.x.y[res$selected.markers]
be <- solve(cov.x) %*% cov.x.y

##### input non White British data
tsv_data <- fread("5_new.tsv", header=TRUE, sep='\t', data.table=FALSE)
pheno_data <- tsv_data[,-c(1,2,3)]
judge_set <- c()
for (i in 1:length(colnames(pheno_data))) {
  if(class(pheno_data[,i]) == "logical"){
    judge_set[i] = TRUE
  }else{
    judge_set[i] = FALSE
  }}
binary_set <- pheno_data[,which(judge_set)]
binary_set1 <- ifelse(binary_set == TRUE, 1, 0)
continuous_set <- pheno_data[,-which(judge_set)]
colnames(continuous_set) <- paste(colnames(continuous_set), "_irnt", sep = "")
total_set <- cbind(binary_set1, continuous_set)
n_white <- total_set[which(total_set[,"21000_1001"] == 0),]
n_whi <- n_white[ ,-which(colnames(n_white) == "22006")]
### dim(whi) = 57160 1755
vari <- c("3526_irnt", res$selected.markers)
if(vari[1] %in% colnames(n_whi)  == FALSE){
  cat("The pheno can not be found","\n")
  q() ## exit programme
}

## out_r2 for ten variables
lm_R2 <- c()
for (i in 1:length(vari)) {
  if(i == 1){
    if(vari[i] %in% colnames(n_whi) == FALSE){
      vari[1] <- NA
      }
  }else{
  if(vari[i] %in% colnames(n_whi) == FALSE){
    vari[i] <- NA
    be[i-1] <- NA
    }
  }
}
va <- na.omit(vari)
b <- na.omit(be)
select_data <- as.matrix(n_whi[, va])
na_fix <- na.omit(select_data)
p <- ncol(na_fix)
q <- nrow(na_fix)
score <- sweep(na_fix[,-1], 2, b, "*")
for (i in 1:length(va[-1])) {
  lm_summary <- summary(lm(na_fix[,1]~ score[,1:i] ))
  lm_R2[i] <- lm_summary$r.squared
}
t <- list(p-1,q,lm_R2[length(lm_R2)])
t

#### setting a circle
pheno_log <- function(num){
res <- sojo.phenotype(sum.stat.discovery = df.sojo, cor.X = xxcor, v.y = yinformat$var, nvar = num)
cov.x <- diag(sqrt(xinformat$var)) %*% cor.x %*% diag(sqrt(xinformat$var))
colnames(cov.x) <- colnames(cor.x)
row.names(cov.x) <- row.names(cor.x)
cov.x.y <- cor.x.y * sqrt(yinformat$var) * sqrt(xinformat$var)
cov.x <- cov.x[res$selected.markers,res$selected.markers]
cov.x.y <- cov.x.y[res$selected.markers]
be <- solve(cov.x) %*% cov.x.y

  vari <- c("3526_irnt", res$selected.markers)

  ## out_r2
  lm_R2 <- c()
  for (i in 2:length(vari)) {
    if(vari[i] %in% colnames(n_whi) == FALSE){
      vari[i] <- NA
      be[i-1] <- NA
    }
  }
  va <- na.omit(vari)
  b <- na.omit(be)
  mark <- as.vector(na.action(b))
  select_data <- as.matrix(n_whi[, va])
  na_fix <- na.omit(select_data)

  select_data <- as.matrix(n_whi[, va])
  na_fix <- na.omit(select_data)
  p <- ncol(na_fix)
  q <- nrow(na_fix)
  
  if(num == 1){
    score <- na_fix[,-1] * as.vector(b)
    lm_summary <- summary(lm(na_fix[,1]~ score ))
    lm_R2[1] <- lm_summary$r.squared
  }
  else{
  score <- sweep(na_fix[,-1], 2, b, "*")
  for (i in 2:length(va[-1])) {
    lm_summary <- summary(lm(na_fix[,1]~ score[,1:i] ))
    lm_R2[i] <- lm_summary$r.squared
   }
  }

  t <- list(va[length(va)], p-1, q, lm_R2[length(lm_R2)], mark)
  return(t)
}

pheno <- c()
var_num <- c()
sam_size <- c()
r2 <- c()
for (i in 1:11) {
  m <- pheno_log(i)
  pheno[i] <- m[[1]]
  var_num[i] <- m[[2]]
  sam_size[i] <- m[[3]]
  r2[i] <- m[[4]]
  om <- m[[5]]
}
if(class(om) != "numeric"){
  s <- data.frame(pheno, var_num, sam_size, r2)
}else{
  s <- data.frame(pheno[-om], var_num[-om], sam_size[-om], r2[-om])
}
s <- data.frame(pheno[-om], var_num[-om], sam_size[-om], r2[-om])
colnames(s) <- c("pheno","var_num", "sam_size", "r2")
write.table(s, file = "out_sample.csv",row.names = FALSE)
read.csv("out_sample.csv",sep = "")

# 
# plot(r2csv[,2],r2csv[,4], lwd = 1, cex = .2, ann = F)
# # text(num,r2csv[,2], labels = paste(1:length(select_var),".",select_var))
# lines(r2csv[,2],r2csv[,4], col = "red", lty = 1, lwd = 2)
# # axis(side=1,at=seq(from=1,by=2,length.out=10),labels=r2csv[,1])
# par(new = TRUE)
# plot(r2csv[,2],r2csv[,4],  lwd = 2, cex = .2,  ann = F, xaxt = "n", yaxt ="n")
# lines(r2csv[,2],r2csv[,4], col = "blue", lty = 1, lwd = 2)
# # text(r2csv[,1],plot_8[,2], labels = paste(1:length(select_var),".",select_var))
# axis(4)
# title(main = "Outsample R2 and Sample Size Change as Variable Number Increase",xlab= 'Variable Numbers')
# legend("bottom", c("Out-of-sample R2 of father", "Out-of-sample R2 of mother"),col = c("red","blue"), pch = c(1,17))
