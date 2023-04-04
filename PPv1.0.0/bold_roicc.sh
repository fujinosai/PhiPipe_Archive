#! /bin/bash

## computing roi-roi correlation matrix
## written by Alex / 2019-01-14 / free_learner@163.com
## revised by Alex / 2019-03-04 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com
## revised by Alex / 2019-09-13 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` computes roi-roi correlation matrix

Usage example:

bash $0 -a /home/alex/data/bold.nii.gz
        -b /home/alex/data
        -c bold
        -d /home/alex/data/roi_atlas.nii.gz

Required arguments:

        -a:  4D bold image
        -b:  output directory
        -c:  output prefix
        -d:  roi mask

Optional arguments:
  
        -e:  roi labels 

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 4 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## bold image
             BOLDIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## roi atlas
             ROI=$OPTARG
             ;;
          e) ## roi labels
             LABEL=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## extracting ROI time series 
bash ${PhiPipe}/roi_stats.sh -a ${BOLDIMAGE} -b ${OUTDIR} -c ${PREFIX} -d ${ROI}

## computing ROI correlation
Rscript -e "Args <- commandArgs(TRUE);\
            roits <- read.table(Args[1]);\
            roicor <- cor(roits);\
            write.table(roicor, Args[2], quote=FALSE, row.names=FALSE, col.names=FALSE);\
           " ${OUTDIR}/${PREFIX}.mean ${OUTDIR}/${PREFIX}.roicc

## rename and add labels
if [[ ! -z ${LABEL} ]]
then
    Rscript -e "Args <- commandArgs(TRUE);\
           roilabels <- read.table(Args[3]);\
           roits <- read.table(Args[1]);\
           names(roits) <- roilabels[,2];\
           write.table(roits, Args[1], quote=FALSE, row.names=FALSE, col.names=TRUE);\
           roiinfo <- read.table(Args[2], header=TRUE);\
           roiinfo <- data.frame(ROI=roilabels[,1], Label=roilabels[,2], roiinfo);\
           write.table(roiinfo, Args[2], quote=FALSE, row.names=FALSE, col.names=TRUE);\
           " ${OUTDIR}/${PREFIX}.mean ${OUTDIR}/${PREFIX}.info ${LABEL}
fi

