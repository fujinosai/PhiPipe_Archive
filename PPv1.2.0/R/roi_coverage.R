## this script was used in roi_stats.sh
## calculate the ratio between non-zero voxels and total voxels in an ROI
Args <- commandArgs(trailingOnly=TRUE)
nzero <- as.data.frame(t(as.matrix(read.table(Args[1]))))
names(nzero) <- c('INDEX','NZERO')
total <- as.data.frame(t(as.matrix(read.table(Args[2]))))
names(total) <- c('INDEX','TOTAL')
roiinfo <- merge(total, nzero, all = TRUE, by = 'INDEX')
## due to signal loss, the ROIs with non-zero signals will be less than the total ROIs
roiinfo[is.na(roiinfo)] <- 0
roiinfo$FRAC <- round(roiinfo$NZERO/roiinfo$TOTAL,4)
write.table(roiinfo, Args[3], quote=FALSE, row.names=FALSE)
