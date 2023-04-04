#! /bin/bash

## create bold brain/wm/csf/parcellation masks and make snapshots for quality check
## written by Alex / 2019-01-09 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com
## revised by Alex / 2019-09-13 / free_learner@163.com
## revised by Alex / 2020-04-09 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` creates bold fMRI brain/wm/csf/parcellation masks and make snapshots for quality check

Usage example:

bash $0 -a /home/alex/data/bold.nii.gz
        -b /home/alex/data
        -c bold
        -d /home/alex/data/t1_brainmask.nii.gz
        -e /home/alex/data/t1_wmmask.nii.gz
        -f /home/alex/data/t1_csfmask.nii.gz
        -g /home/alex/data/t1_DKAseg.nii.gz
        -h /home/alex/data/bold2t1.mat
        -i /home/alex/data/boldref.nii.gz

Required arguments:

        -a: 4D bold fMRI images  
        -b: output directory
        -c: output prefix
        -d: t1 brain mask
        -e: t1 white matter mask
        -f: t1 csf mask
        -g: t1 DK+Aseg atlas mask
        -h: bold-T1 BBR registration matrix (ANTs format)
        -i: reference file

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 9 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:i:" OPT
    do
      case $OPT in
          a) ## bold fMRI image file
             BOLDIMAGE=$OPTARG
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
          e) ## t1 wm mask
             T1WMMASK=$OPTARG
             ;;
          f) ## t1 csf mask
             T1CSFMASK=$OPTARG
             ;;
          g) ## t1 DK+Aseg atlas mask
             T1DKASEG=$OPTARG
             ;;
          h) ## BBR registration matrix
             BBRMAT=$OPTARG
             ;;
          i) ## reference file
             REFIMAGE=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

# brain mask
3dAutomask -dilate 1 -prefix ${OUTDIR}/mytmp_automask.nii.gz ${BOLDIMAGE}
bash ${PhiPipe}/apply_transform.sh -a 0 -b ${T1BRAINMASK} -c ${OUTDIR}/mytmp_brainmask.nii.gz -d ${REFIMAGE} -e [${BBRMAT},1] -f NearestNeighbor
3dmask_tool -input ${OUTDIR}/mytmp_brainmask.nii.gz -dilate_input 1 -prefix ${OUTDIR}/mytmp_brainmask_dilt.nii.gz
3dcalc -a ${OUTDIR}/mytmp_brainmask_dilt.nii.gz -b ${OUTDIR}/mytmp_automask.nii.gz -expr 'a*b' -prefix ${OUTDIR}/${PREFIX}_brainmask.nii.gz 
# wm mask
bash ${PhiPipe}/apply_transform.sh -a 0 -b ${T1WMMASK} -c ${OUTDIR}/mytmp_wmmask.nii.gz -d ${REFIMAGE} -e [${BBRMAT},1] -f NearestNeighbor
3dmask_tool -input ${OUTDIR}/mytmp_wmmask.nii.gz -dilate_input -1 -prefix ${OUTDIR}/mytmp_wmmask_ero.nii.gz
3dcalc -a ${OUTDIR}/mytmp_wmmask_ero.nii.gz -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -expr 'a*b' -prefix ${OUTDIR}/${PREFIX}_wmmask.nii.gz
3dmaskave -mask ${OUTDIR}/${PREFIX}_wmmask.nii.gz -quiet ${BOLDIMAGE} > ${OUTDIR}/${PREFIX}_wmmean.txt
# csf mask
bash ${PhiPipe}/apply_transform.sh -a 0 -b ${T1CSFMASK} -c ${OUTDIR}/mytmp_csfmask.nii.gz -d ${REFIMAGE} -e [${BBRMAT},1] -f Linear
3dcalc -a ${OUTDIR}/mytmp_csfmask.nii.gz -expr 'ispositive(a-0.9)' -prefix ${OUTDIR}/mytmp_csfmask_ero.nii.gz
3dcalc -a ${OUTDIR}/mytmp_csfmask_ero.nii.gz -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -expr 'a*b' -prefix ${OUTDIR}/${PREFIX}_csfmask.nii.gz
3dmaskave -mask ${OUTDIR}/${PREFIX}_csfmask.nii.gz -quiet ${BOLDIMAGE} > ${OUTDIR}/${PREFIX}_csfmean.txt
# DK+Aseg mask
bash ${PhiPipe}/apply_transform.sh -a 0 -b ${T1DKASEG} -c ${OUTDIR}/${PREFIX}_DKAseg.nii.gz -d ${REFIMAGE} -e [${BBRMAT},1] -f NearestNeighbor

## remove temporary files
rm ${OUTDIR}/mytmp*

## check bold masks
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_brainmask -e 1 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_wmmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_wmmask -e 0 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_csfmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_csfmask -e 0 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_DKAseg.nii.gz -c ${OUTDIR} -d ${PREFIX}_DKAseg -e 0 -f 1

