## this script was used in roi_stats.sh
## add ROI labels
Args <- commandArgs(trailingOnly=TRUE)
roilabels <- read.table(Args[3])
names(roilabels) <- c('INDEX','LABEL')
roidat <- read.table(Args[1])
roiinfo <- read.table(Args[2], header=TRUE)
names(roidat) <- roilabels[,2]
roiinfo <- merge(roilabels, roiinfo, by = 'INDEX')
write.table(roidat, Args[1], quote=FALSE, row.names=FALSE, col.names=TRUE)
write.table(roiinfo, Args[2], quote=FALSE, row.names=FALSE, col.names=TRUE)
