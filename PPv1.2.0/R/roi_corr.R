## this script was used in bold_roicc.sh
## calculate the correlation matrix using ROI mean signals
Args <- commandArgs(trailingOnly=TRUE)
roits <- read.table(Args[1])
roicor <- cor(roits, method = 'pearson')
write.table(roicor, Args[2], quote=FALSE, row.names=FALSE, col.names=FALSE)