#! /bin/bash

## calculating ReHo using AFNI's 3dReHo
## written by Alex / 2019-01-14 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` calculates Regional Homogeneity (ReHo)

Usage example:

bash $0 -a /home/alex/data/bold.nii.gz
        -b /home/alex/data
        -c bold_reho
        -d /home/alex/data/bold_brainmask.nii.gz

Required arguments:

        -a:  4D bold image
        -b:  output directory
        -c:  output prefix

Optional arguments:
 
        -d:  whole brain mask 
        -e:  number of neighbours
        -f:  disable zscoring

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 3 ]] ; then
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
3dReHo -prefix ${OUTDIR}/mytmp_reho.nii.gz \
       -inset ${BOLDIMAGE} \
       -mask ${MASK} \
       -nneigh ${NN}

## if zscoring
if [[ -z ${NZ} ]]
then
    bash ${PhiPipe}/zscore_image.sh -a ${OUTDIR}/mytmp_reho.nii.gz -b ${OUTDIR} -c ${PREFIX} -d ${MASK}
else
    mv ${OUTDIR}/mytmp_reho.nii.gz ${OUTDIR}/${PREFIX}.nii.gz
fi

## remove temporary files
rm ${OUTDIR}/mytmp*
