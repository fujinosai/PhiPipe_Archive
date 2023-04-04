library(stringr)

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## create SchaeferAseg labels
idx <- c(10:13,17:18,26,49:54,58,1001:1050, 2001:2050)
## the Schaefer2018_100Parcels_7Networks_order_LUT file could be found in Yeolab's Github page
luts <- read.table('Schaefer2018_100Parcels_7Networks_order_LUT.txt',col.names = c('ID','LABEL','R','G','B','UNKNOWN'))
labels <- luts[luts$ID %in% idx,c(1,2)]
## remove extra characters to make the label shorter
labels$LABEL <- str_replace_all(labels$LABEL, '7Networks_','')
write.table(labels, 'Schaefer.100Parcels.7Networks.Aseg_labels.txt', row.names = FALSE, col.names = FALSE, quote = FALSE)
## save the luts for visualization purpose
idx <- c(0, idx)
luts <- luts[luts$ID %in% idx,]
write.table(luts, 'Schaefer2018_100Parcels_7Networks_LUT.txt', row.names = FALSE, col.names = FALSE, quote = FALSE)
file.remove('Schaefer2018_100Parcels_7Networks_order_LUT.txt')
