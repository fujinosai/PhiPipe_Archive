#! /bin/bash

## convert 3D image into z score (zero mean, unit standard deviation)
## written by Alex / 2019-01-14 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` converts 3D image into z score (zero mean, unit standard deviation)

Usage example:

bash $0 -a /home/alex/data/bold_reho.nii.gz
        -b /home/alex/data
        -c bold_zreho
        -d /home/alex/data/bold_brainmask.nii.gz

Required arguments:

        -a:  3D image
        -b:  output directory
        -c:  output prefix
        -d:  brain mask 

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 4 ]] ; then
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

## zscoring
STATS=($(3dmaskave -mask ${MASK} -sigma -quiet ${IMAGE}))
3dcalc -a ${IMAGE} -b ${MASK} -expr "(a - ${STATS[0]} )/${STATS[1]}*b" -prefix ${OUTDIR}/${PREFIX}.nii.gz
