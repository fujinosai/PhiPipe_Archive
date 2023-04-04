#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------------------------------
`basename $0` computes ROI-ROI connectivity matrix by averaging voxel-wise correlations
-----------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold.nii.gz
        -b /home/alex/output
        -c bold_vwroicc
        -d /home/alex/input/roi_atlas.nii.gz
-----------------------------------------------------------------------------------------
Required arguments:
        -a:  4D BOLD image
        -b:  output directory
        -c:  output prefix
        -d:  ROI mask

Optional arguments:
        -e:  ROI labels 
-----------------------------------------------------------------------------------------
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

## if PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]
then
    echo "Please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if INPUT file/OUTPUT folder exist?
if [[ ! -z ${LABEL} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${ROI} -a ${LABEL} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${ROI} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## ROI coverage and averaged voxel-wise correlation
if [[ ! -z ${LABEL} ]]
then
    Rscript ${PhiPipe}/R/roi_vwcorr.R ${BOLDIMAGE} ${ROI} ${OUTDIR}/${PREFIX}.matrix ${OUTDIR}/${PREFIX}.info ${LABEL}
else
    Rscript ${PhiPipe}/R/roi_vwcorr.R ${BOLDIMAGE} ${ROI} ${OUTDIR}/${PREFIX}.matrix ${OUTDIR}/${PREFIX}.info
fi

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.matrix -a ${OUTDIR}/${PREFIX}.info
if [[ $? -eq 1 ]]
then
    exit 1
fi
