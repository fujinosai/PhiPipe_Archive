## this script was used in bold_exslicetime.sh
## extract the slice timing information from the JSON file created by dcm2niix
library(jsonlite)
Args <- commandArgs(trailingOnly=TRUE)
jsonfile <- fromJSON(Args[1])
stfile <- jsonfile$SliceTiming
## convert seconds into milliseconds
if (Args[3] != 0){
  stfile <- stfile * 1000
}
write.table(stfile, Args[2], col.names=FALSE, row.names=FALSE)
