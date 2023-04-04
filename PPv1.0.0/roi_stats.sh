#! /bin/bash

## get roi statistics using AFNI's 3dROIstats
## written by Alex / 2019-01-15 / free_learner@163.com
## revised by Alex / 2019-03-04 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com
## revised by Alex / 2019-09-13 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` gets roi statistics using AFNI's 3dROIstats

Usage example:

bash $0 -a /home/alex/data/bold_reho.nii.gz
        -b /home/alex/data
        -c bold_roireho
        -d /home/alex/data/roi_atlas.nii.gz
        -e /home/alex/data/roi_labels.txt

Required arguments:

        -a:  3D image
        -b:  output directory
        -c:  output prefix
        -d:  roi atlas

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
          a) ## 3D image
             IMAGE=$OPTARG
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

## get roi stats
3dROIstats -mask ${ROI} -quiet -nomeanout -nzmean ${IMAGE} > ${OUTDIR}/${PREFIX}.mean 

## calculate roi coverage due to signal loss in bold fMRI
if [[ $(fslnvols ${IMAGE}) -gt 1 ]]
then
   3dTstat -mean -prefix ${OUTDIR}/mytmp_mean.nii.gz ${IMAGE}
   3dROIstats -mask ${ROI} -quiet -nomeanout -nzvoxels ${OUTDIR}/mytmp_mean.nii.gz > ${OUTDIR}/mytmp_nvoxel.txt
else
   3dROIstats -mask ${ROI} -quiet -nomeanout -nzvoxels ${IMAGE} > ${OUTDIR}/mytmp_nvoxel.txt
fi
3dROIstats -mask ${ROI} -quiet -nomeanout -nzvoxels ${ROI} > ${OUTDIR}/mytmp_ntotal.txt
Rscript -e "Args <- commandArgs(TRUE);\
            nvoxel <- scan(Args[1]);\
            ntotal <- scan(Args[2]);\
            roiinfo <- data.frame(Nvol=nvoxel, Nzero=ntotal-nvoxel, frac=round(nvoxel/ntotal,4));\
            write.table(roiinfo, Args[3], quote=FALSE, row.names=FALSE);\
           " ${OUTDIR}/mytmp_nvoxel.txt ${OUTDIR}/mytmp_ntotal.txt ${OUTDIR}/${PREFIX}.info

## if roi label exists?
if [[ ! -z ${LABEL} ]]
then
     Rscript -e "Args <- commandArgs(TRUE);\
          roilabels <- read.table(Args[3]);\
          roidat <- read.table(Args[1]);\
          roiinfo <- read.table(Args[2], header=TRUE);\
          names(roidat) <- roilabels[,2];\
          roiinfo <- data.frame(ROI=roilabels[,1], Label=roilabels[,2],roiinfo);\
          write.table(roidat, Args[1], quote=FALSE, row.names=FALSE, col.names=TRUE);\
          write.table(roiinfo, Args[2], quote=FALSE, row.names=FALSE, col.names=TRUE);\
         " ${OUTDIR}/${PREFIX}.mean ${OUTDIR}/${PREFIX}.info ${LABEL}
fi

## remove temporary file
rm ${OUTDIR}/mytmp*
