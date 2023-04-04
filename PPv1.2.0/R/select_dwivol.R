## this script was used in dwi_dtifit.sh
## select the volumes with lowest non-zero b-value if multi-shell data is detected
Args <- commandArgs(trailingOnly=TRUE)
bvals <- scan(Args[1])
idx <- numeric(length=length(bvals))
## if b-value < 100, these volumes were with a zero b-value
idx <- ifelse(bvals<100, TRUE, FALSE)
## the range of non-zero b-value
minmax <- range(bvals[!idx])
bdiff <- minmax[2] - minmax[1]
## if the difference between the highest and lowest b values > 100, the data is multi-shelled
if ( bdiff > 100){
   ## if the b values < lowest b value + 100, these b values were regarded as the same
   ## the b0 volumes were also included
   idx <- which(idx | (bvals - minmax[1]) < 100)
   bvecs <- read.table(Args[2])
   ## volume index starts at 0, so minus 1
   write.table(t(idx-1), Args[3], quote=FALSE, row.names=FALSE, col.names=FALSE, sep=',')
   ## the corresponding b-value and b-vector files
   write.table(t(bvals[idx]), Args[4], quote=FALSE, row.names=FALSE, col.names=FALSE)
   write.table(bvecs[,idx], Args[5], quote=FALSE, row.names=FALSE, col.names=FALSE)
}
