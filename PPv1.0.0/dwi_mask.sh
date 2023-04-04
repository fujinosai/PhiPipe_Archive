#! /bin/bash

## create dwi brain/parcellation masks and make snapshots for quality check
## written by Alex / 2019-09-03 / free_learner@163.com
## revised by Alex / 2019-09-11 / free_learner@163.com
## revised by Alex / 2020-04-02 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` creates dwi brain/parcellation masks and makes snapshots for quality check

Usage example:

bash $0 -a /home/alex/data/dwi_b0.nii.gz
        -b /home/alex/data
        -c dwi
        -d /home/alex/data/t1_brainmask.nii.gz
        -e /home/alex/data/t1_DKAseg.nii.gz
        -f /home/alex/data/dwi2t1.mat

Required arguments:

        -a: dwi b0 image
        -b: output directory
        -c: output prefix
        -d: t1 brain mask
        -e: t1 DKAseg mask
        -f: dwi-T1 BBR registration matrix (ANTs format)

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## dwi b0 image file
             B0IMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## t1 brain mask
             T1BRAINMASK=$OPTARG
             ;;
          e) ## t1 DK+Aseg atlas mask
             T1DKASEG=$OPTARG
             ;;
          f) ## BBR registration matrix
             BBRMAT=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi
          
REFIMAGE=${B0IMAGE}
# brain mask
bet2 ${B0IMAGE} ${OUTDIR}/mytmp_bet -f 0.2 -m ## -f 0.2 to avoid removing brain tissues
bash ${PhiPipe}/apply_transform.sh -a 0 -b ${T1BRAINMASK} -c ${OUTDIR}/mytmp_brainmask.nii.gz -d ${REFIMAGE} -e [${BBRMAT},1] -f NearestNeighbor
3dmask_tool -input ${OUTDIR}/mytmp_brainmask.nii.gz -dilate_input 1 -prefix ${OUTDIR}/mytmp_brainmask_dilt.nii.gz
3dcalc -a ${OUTDIR}/mytmp_brainmask_dilt.nii.gz -b ${OUTDIR}/mytmp_bet_mask.nii.gz -expr 'a*b' -prefix ${OUTDIR}/${PREFIX}_brainmask.nii.gz

# DK+Aseg mask
bash ${PhiPipe}/apply_transform.sh -a 0 -b ${T1DKASEG} -c ${OUTDIR}/${PREFIX}_DKAseg.nii.gz -d ${REFIMAGE} -e [${BBRMAT},1] -f NearestNeighbor

## remove temporary files
rm ${OUTDIR}/mytmp*

## check dwi masks
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_brainmask -e 1 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_DKAseg.nii.gz -c ${OUTDIR} -d ${PREFIX}_DKAseg -e 0 -f 1

