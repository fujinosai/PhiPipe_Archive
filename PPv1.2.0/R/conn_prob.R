## this script was used in dwi_probtrackx.sh
## calculate the structural connectivity probability matrix based on the fdt_network_matrix file
Args <- commandArgs(trailingOnly=TRUE)
countMat <- as.matrix(read.table(Args[1]))
NROI <- nrow(countMat)
roiInfo <- read.table(Args[2], header = TRUE)
probMat <- matrix(0,nrow=NROI,ncol=NROI)
## normalize the count matrix by the total number of samples (voxel size * 5000) seeded from each ROI
probMat <- countMat/matrix(rep(roiInfo$NZERO,NROI), nrow=NROI)/5000;
probMat <- (probMat + t(probMat))/2
write.table(probMat, Args[3], quote=FALSE, row.names=FALSE, col.names=FALSE)
