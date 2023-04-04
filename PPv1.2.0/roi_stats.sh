#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
------------------------------------------------------------------
`basename $0` extracts ROI mean signal and coverage information
------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold_reho.nii.gz
        -b /home/alex/output
        -c bold_roireho
        -d /home/alex/input/roi_atlas.nii.gz
        -e /home/alex/input/roi_labels.txt
------------------------------------------------------------------
Required arguments:
        -a:  3D/4D image
        -b:  output directory
        -c:  output prefix
        -d:  ROI mask

Optional arguments:
        -e:  ROI labels 
------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 8 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## 3D/4D image
             IMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## ROI mask
             ROI=$OPTARG
             ;;
          e) ## ROI labels
             LABEL=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
    done
fi

## if PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]
then
    echo "Please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if INPUT file/OUTPUT folder exist?
if [[ ! -z ${LABEL} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${IMAGE} -a ${ROI} -a ${LABEL} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${IMAGE} -a ${ROI} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## calculate the mean of non-zero voxels in each ROI
## the number of ROIs would be automatically figured out
3dROIstats -mask ${ROI} -quiet -nomeanout -nzmean ${IMAGE} > ${OUTDIR}/${PREFIX}.mean 

## calculate ROI coverage due to signal loss in BOLD fMRI
if [[ $(fslnvols ${IMAGE}) -gt 1 ]]
then
    ## for 4D data, use standard deviation > 0 to find non-zero voxels
    3dTstat -nzstdev -prefix ${OUTDIR}/mytmp_std.nii.gz ${IMAGE}
    ## the -1DRformat option was included to output the ROI indices
    3dROIstats -mask ${ROI} -nomeanout -nzvoxels -1DRformat ${OUTDIR}/mytmp_std.nii.gz | cut -f1 --complement | sed s/NZcount_//g > ${OUTDIR}/mytmp_nzero.txt
else
    3dROIstats -mask ${ROI} -nomeanout -nzvoxels -1DRformat ${IMAGE} | cut -f1 --complement | sed s/NZcount_//g > ${OUTDIR}/mytmp_nzero.txt
fi
## the total number of voxels in each ROI
3dROIstats -mask ${ROI} -nomeanout -nzvoxels -1DRformat ${ROI} | cut -f1 --complement | sed s/NZcount_//g > ${OUTDIR}/mytmp_total.txt

## calculate the coverage info
Rscript ${PhiPipe}/R/roi_coverage.R ${OUTDIR}/mytmp_nzero.txt ${OUTDIR}/mytmp_total.txt ${OUTDIR}/${PREFIX}.info

## if ROI label exists?
if [[ ! -z ${LABEL} ]]
then
    Rscript ${PhiPipe}/R/roi_label.R ${OUTDIR}/${PREFIX}.mean ${OUTDIR}/${PREFIX}.info ${LABEL}
fi

## remove temporary file
rm ${OUTDIR}/mytmp*

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.mean -a ${OUTDIR}/${PREFIX}.info
if [[ $? -eq 1 ]]
then
    exit 1
fi
