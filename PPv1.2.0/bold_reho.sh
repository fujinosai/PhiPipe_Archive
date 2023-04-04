#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------------------
`basename $0` calculates Regional Homogeneity (ReHo) of BOLD fMRI images
---------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold.nii.gz
        -b /home/alex/output
        -c bold_reho
        -d /home/alex/input/bold_brainmask.nii.gz
---------------------------------------------------------------------------
Required arguments:
        -a:  4D BOLD image
        -b:  output directory
        -c:  output prefix

Optional arguments:
        -d:  whole brain mask 
        -e:  number of neighbours
        -f:  disable zscoring
---------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:" OPT
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
          d) ## whole brain mask
             MASK=$OPTARG
             ;;
          e) ## number of neighbours
             NN=$OPTARG
             ;;
          f) ## disable zscoring
             NZ=$OPTARG
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
if [[ ! -z ${MASK} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${MASK} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## if a whole brain mask provided?
if [[ -z ${MASK} ]]
then
    3dAutomask -prefix ${OUTDIR}/mytmp_mask.nii.gz ${BOLDIMAGE}
    MASK=${OUTDIR}/mytmp_mask.nii.gz
fi

## the number of neighbours
if [[ -z ${NN} ]]
then
    NN=27
fi

## ReHo calculation
3dReHo -prefix ${OUTDIR}/mytmp_reho.nii.gz -inset ${BOLDIMAGE} -mask ${MASK} -nneigh ${NN}

## if zscoring
if [[ -z ${NZ} ]]
then
    bash ${PhiPipe}/zscore_image.sh -a ${OUTDIR}/mytmp_reho.nii.gz -b ${OUTDIR} -c ${PREFIX} -d ${MASK}
else
    mv ${OUTDIR}/mytmp_reho.nii.gz ${OUTDIR}/${PREFIX}.nii.gz
fi

## remove temporary files
rm ${OUTDIR}/mytmp*

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
