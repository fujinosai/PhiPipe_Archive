#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------
`basename $0` calculates ALFF/fALFF of BOLD fMRI images
-----------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold.nii.gz
        -b /home/alex/output
        -c bold
        -d 0.01
        -e 0.1
        -f 2
        -g /home/alex/input/bold_brainmask.nii.gz
-----------------------------------------------------------
Required arguments:
        -a:  4D BOLD image
        -b:  output directory
        -c:  output prefix
        -d:  high pass frequency
        -e:  low pass frequency
        -f:  repetition time
-----------------------------------------------------------
Optional arguments:
        -g:  whole brain mask
        -h:  disable zscoring
-----------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 12 ]]
then
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

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_alff.nii.gz -a ${OUTDIR}/${PREFIX}_falff.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
