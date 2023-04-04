#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-------------------------------------------------------------------------
`basename $0` computes ROI-ROI correlation matrix using ROI mean signals
-------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold.nii.gz
        -b /home/alex/output
        -c bold_roicc
        -d /home/alex/input/roi_atlas.nii.gz
-------------------------------------------------------------------------
Required arguments:
        -a:  4D BOLD image
        -b:  output directory
        -c:  output prefix
        -d:  ROI mask

Optional arguments:
        -e:  ROI labels 
-------------------------------------------------------------------------
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
          a) ## BOLD image
             BOLDIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## ROI atlas
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
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${ROI} -a ${LABEL} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${ROI} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## extracting ROI time series 
bash ${PhiPipe}/roi_stats.sh -a ${BOLDIMAGE} -b ${OUTDIR} -c ${PREFIX} -d ${ROI}

## computing ROI correlation matrix
Rscript ${PhiPipe}/R/roi_corr.R ${OUTDIR}/${PREFIX}.mean ${OUTDIR}/${PREFIX}.matrix

## add labels if exist
if [[ ! -z ${LABEL} ]]
then
    Rscript ${PhiPipe}/R/roi_label.R ${OUTDIR}/${PREFIX}.mean ${OUTDIR}/${PREFIX}.info ${LABEL}
fi

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.mean -a ${OUTDIR}/${PREFIX}.info ${OUTDIR}/${PREFIX}.matrix
if [[ $? -eq 1 ]]
then
    exit 1
fi
