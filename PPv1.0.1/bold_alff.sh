#! /bin/bash

## calculating ALFF/fALFF using AFNI's 3dRSFC
## written by Alex / 2019-01-14 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` calculates ALFF/fALFF using AFNI's 3dRSFC

Usage example:

bash $0 -a /home/alex/data/bold.nii.gz
        -b /home/alex/data
        -c bold
        -d fbot
        -e ftop
        -f 2
        -g /home/alex/data/bold_brainmask.nii.gz

Required arguments:

        -a:  4D bold image
        -b:  output directory
        -c:  output prefix
        -d:  fbot
        -e:  ftop
        -f:  repetition time

Optional arguments:

        -g:  whole brain mask
        -h:  disable zscoring

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:" OPT
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
          d) ## high pass frequency
             FBOT=$OPTARG
             ;;
          e) ## low pass frequency
             FTOP=$OPTARG
             ;;
          f) ## repetition time
             TR=$OPTARG
             ;;
          g) ## whole brain mask
             MASK=$OPTARG
             ;;
          h) ## disable zscoring
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

## calculating ALFF/fALFF
3dRSFC -nodetrend -dt ${TR} -mask ${MASK} -no_rs_out -no_rsfa -notrans -prefix ${OUTDIR}/${PREFIX} ${FBOT} ${FTOP} ${BOLDIMAGE}
3dAFNItoNIFTI -prefix ${OUTDIR}/mytmp_alff.nii.gz ${OUTDIR}/${PREFIX}_ALFF*
3dAFNItoNIFTI -prefix ${OUTDIR}/mytmp_falff.nii.gz ${OUTDIR}/${PREFIX}_fALFF*
rm ${OUTDIR}/${PREFIX}_*.BRIK ${OUTDIR}/${PREFIX}_*.HEAD

## if zscoring
for meas in alff falff
do
    if [[ -z ${NZ} ]]
    then
        bash ${PhiPipe}/zscore_image.sh -a ${OUTDIR}/mytmp_${meas}.nii.gz -b ${OUTDIR} -c ${PREFIX}_${meas} -d ${MASK}
    else
        mv ${OUTDIR}/mytmp_${meas}.nii.gz ${OUTDIR}/${PREFIX}_${meas}.nii.gz
    fi
done

## remove temporary files
rm ${OUTDIR}/mytmp*

