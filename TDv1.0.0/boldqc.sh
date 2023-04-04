#! /bin/bash

## quality check of bold fMRI images
## written by Alex / 2019-02-16 / free_learner@163.com
## revised by Alex / 2020-04-24 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` quality check of bold fMRI images

Usage example:

bash $0 -a /home/alex/data/sub001 -b /home/alex/data/sub001/qc

Required arguments:

        -a:  input directory containing bold images
        -b:  output directory containing QC results

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 2 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:" OPT
    do
      case $OPT in
          a) ## input directory
             INPUT=$OPTARG
             ;;
          b) ## output directory
             OUTPUT=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## check if input files exit
NFILE=$(ls ${INPUT}/*.nii* | wc -l)
if [[ ${NFILE} -eq 0 ]]
then
    echo "WARNING: no input files found. Please check!!!"
    exit
fi

for BOLDDATA in $(ls ${INPUT}/*.nii*)
do
    ## get the filename
    INPUTBASE=$(basename ${BOLDDATA} | xargs remove_ext)
    ## make output directory
    OUTPUTDIR=${OUTPUT}/${INPUTBASE}
    mkdir -p ${OUTPUTDIR}
    ## check time points
    NVOL=$(fslnvols ${BOLDDATA})
    ## check head motion
    mcflirt -in ${BOLDDATA} -out ${OUTPUTDIR}/bold_mc -plots -spline_final
    THRESH=0.5
    Rscript -e "Args <- commandArgs(TRUE);\
    fname <- paste(Args[1],'/bold_mc.par', sep='');\
    mc <- as.matrix(read.table(fname));\
    mc[,1:3] <- mc[,1:3]*50;\
    fd <-rowSums(abs(rbind(0,diff(mc))));meanfd <- mean(fd);\
    fdratio <- sum(fd > Args[2])/length(fd);\
    mc_metric <- setNames(c(Args[3],meanfd,fdratio), c('NVOL:','MeanFD:','OutlierRatio:'));\
    fname <- paste(Args[1], '/bold_mc.metric', sep='');\
    write.table(mc_metric, fname, quote=FALSE, row.names=TRUE, col.names=FALSE);" ${OUTPUTDIR} ${THRESH} ${NVOL}
done
