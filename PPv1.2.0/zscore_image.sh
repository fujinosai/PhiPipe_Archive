#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------------------------
`basename $0` converts 3D image into Z-score (zero mean, unit standard deviation)
-----------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold_reho.nii.gz
        -b /home/alex/output
        -c bold_zreho
        -d /home/alex/input/bold_brainmask.nii.gz
-----------------------------------------------------------------------------------
Required arguments:
        -a:  3D image
        -b:  output directory
        -c:  output prefix
        -d:  brain mask 
-----------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 8 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:" OPT
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
          d) ## brain mask
             MASK=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -a ${IMAGE} -a ${MASK} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## zscoring
STATS=($(3dmaskave -mask ${MASK} -sigma -quiet ${IMAGE}))
3dcalc -a ${IMAGE} -b ${MASK} -expr "(a - ${STATS[0]} )/${STATS[1]}*b" -prefix ${OUTDIR}/${PREFIX}.nii.gz

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
