library(stringr)

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## create DKAseg labels
## the indices were obtained by checking the finally generated parcellation file
idx <- c(10:13,17:18,26,49:54,58,1001:1003,1005:1035, 2001:2003,2005:2035)
luts <- read.table(paste(Sys.getenv("FREESURFER_HOME"),'/FreeSurferColorLUT.txt',sep=''),col.names = c('ID','LABEL','R','G','B','UNKNOWN'))
labels <- luts[luts$ID %in% idx,c(1,2)]
## remove extra characters to make the label shorter
labels$LABEL <- str_replace_all(labels$LABEL, 'ctx-','')
write.table(labels, 'DKAseg_labels.txt', row.names = FALSE, col.names = FALSE, quote = FALSE)
## save the luts for visualization purpose
idx <- c(0, idx)
luts <- luts[luts$ID %in% idx,]
write.table(luts, 'DKAseg_LUT.txt', row.names = FALSE, col.names = FALSE, quote = FALSE)
