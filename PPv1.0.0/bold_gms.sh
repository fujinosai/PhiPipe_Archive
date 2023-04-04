#! /bin/bash

## grand mean scaling
## written by Alex / 2019-01-09 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` performs grand mean scaling

Usage example:

bash $0 -a /home/alex/data/bold.nii.gz
        -b /home/alex/data
        -c bold_gms
        -d /home/alex/data/bold_brainmask.nii.gz

Required arguments:

        -a:  4D bold image
        -b:  output directory
        -c:  output prefix

Optional arguments:
         
        -d:  bold brain mask

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 3 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:" OPT
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
          d) ## mask
             MASK=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## whether a mask provided
if [[ -z ${MASK} ]]
then
    3dAutomask -prefix ${OUTDIR}/mytmp_mask.nii.gz ${BOLDIMAGE}
    MASK=${OUTDIR}/mytmp_mask.nii.gz
fi

## grand mean scaling to 10000
3dTstat -mean -mask ${MASK} -prefix ${OUTDIR}/mytmp_mean.nii.gz ${BOLDIMAGE}
GRANDMEAN=$(3dmaskave -mask ${MASK} -quiet ${OUTDIR}/mytmp_mean.nii.gz)
3dcalc -a ${BOLDIMAGE} -b ${MASK} -expr "a*10000/${GRANDMEAN}*b" -prefix ${OUTDIR}/${PREFIX}.nii.gz

## remove temporary files
rm ${OUTDIR}/mytmp*
