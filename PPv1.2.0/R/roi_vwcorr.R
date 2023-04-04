## this script was used in bold_vwroicc.sh
## calculate the average voxel-wise correlation in any two ROIs
## the current implementation is very inefficient and time-consuming.
library(oro.nifti)
Args <- commandArgs(trailingOnly=TRUE)
## read the BOLD fMRI data and ROI mask
boldimg <- readNIfTI(Args[1], reorient=FALSE)
roimask <- readNIfTI(Args[2], reorient=FALSE)
## the size of the array
sz <- dim(roimask@.Data)
roimask1D <- matrix(roimask@.Data, nrow=sz[1]*sz[2]*sz[3], ncol=1)
## obtain the ROI index and remove the first one (0)
roiidx <- sort(unique(roimask1D), decreasing = FALSE)[-1]
N <- length(roiidx)
## calculate the ROI coverage
voxMat <- matrix(0,nrow=N, ncol=3)
## the total voxels in each ROI
for (i in 1:N){
  voxMat[i,1] <- roiidx[i]
  voxMat[i,2] <- sum(roimask1D == roiidx[i])
}
## the non-zero voxels in BOLD fMRI data
boldimg2D <- matrix(boldimg@.Data, nrow=sz[1]*sz[2]*sz[3])
voxstd <- apply(boldimg2D, 1, sd)
voxstd[voxstd > 0] <- 1
roimask1D <- voxstd * roimask1D
for (i in 1:N){
  voxMat[i,3] <- sum(roimask1D == roiidx[i])
}
## create the roiinfo dataframe
roiinfo <- data.frame(INDEX=voxMat[,1], TOTAL=voxMat[,2], NZERO=voxMat[,3],FRAC=round(voxMat[,3]/voxMat[,2],4))
## if label file provided
if ( length(Args) == 5 ){
  roilabels <- read.table(Args[5])
  names(roilabels) <- c('INDEX','LABEL')
  roiinfo <- merge(roilabels, roiinfo, by = 'INDEX')
}
## save the ROI coverage data
write.table(roiinfo, Args[4], quote=FALSE, row.names=FALSE)
## get the ROI indices with non-zero voxels
nzroiidx <- sort(unique(roimask1D), decreasing = FALSE)[-1]
corMat <- matrix(0, nrow = N, ncol = N)
## loop through all ROIs
for (i in 1:N){
  for (j in 1:i){
            ## if both ROIs with non-zero voxels
            if (roiidx[i] %in% nzroiidx && roiidx[j] %in% nzroiidx){
               tmp1 <- boldimg2D[roimask1D == roiidx[i],,drop=FALSE]
               tmp2 <- boldimg2D[roimask1D == roiidx[j],,drop=FALSE]
               tmpcor <- cor(t(tmp1), t(tmp2))
               ## if the ROIs were the same, use lower-triangular elements
               if (i == j){
                  tmpcor <- atanh(tmpcor[lower.tri(tmpcor, diag = FALSE)])
               }else{
                  tmpcor <- atanh(tmpcor)
               }
               ## if infinite value exists, possibly due to interpolation effect on the brain edge
               Infidx <- is.infinite(tmpcor)
               if (sum(Infidx) >0){
                 tmpcor <- tmpcor[!Infidx]
               }
               corMat[i,j] <- mean(tmpcor)
            }else{
                  corMat[i,j] <- NA
            }
            ## filling the symmetric element
            if (i != j){
            corMat[j,i] <- corMat[i,j]
            }
  }
} 
write.table(corMat, Args[3], quote=FALSE, row.names=FALSE, col.names=FALSE)
