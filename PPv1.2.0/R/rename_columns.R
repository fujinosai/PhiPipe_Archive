## this script was used in t1_stats.sh
## rename the column names of BN Atlas stats file
Args <- commandArgs(trailingOnly=TRUE)
## stats file containing morphological measures for each region
dat <- read.table(Args[1],header=TRUE)
## label file containing the correct region labels
labels <- read.table(Args[2],header=FALSE)
labels <- as.character(labels[,2])
## measure name so that different measure could be treated differently
meas <- Args[3]
## the order of regions is different between stats file and label file
if (meas == "volume"){
  names(dat)[c(1:105,106:210)] <- c(labels[seq(1,210,2)],labels[seq(2,210,2)])            
}else{
  names(dat)[c(1:105,107:211)] <- c(labels[seq(1,210,2)],labels[seq(2,210,2)])
}
write.table(dat, Args[1], quote=FALSE, row.names=FALSE, col.names = TRUE)