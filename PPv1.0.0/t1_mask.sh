#! /bin/bash

## create brain/wm/csf/subcortical masks from FreeSurfer recon-all results and make snapshots for quality check
## written by Alex / 2019-01-08 / free_learner@163.com 
## revised by Alex / 2019-06-25 / free_learner@163.com
## revised by Alex / 2019-09-12 / free_learner@163.com
## revised by Alex / 2020-04-07 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` creates brain/wm/csf/subcortical masks from FreeSurfer recon-all results and make snapshots for quality check

Usage example:

bash $0 -a /home/alex/data/freesurfer -b /home/alex/data/freesurfer/masks  -c t1

Required arguments:

        -a:  FreeSurfer recon-all directory
        -b:  output directory
        -c:  output prefix 

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 3 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:" OPT
    do
      case $OPT in
          a) ## recon-all directory
             RECONALL=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## create masks based FreeSurfer's parcellation results
mri_convert ${RECONALL}/mri/nu.mgz ${OUTDIR}/${PREFIX}_biascorrect.nii.gz
mri_binarize --i ${RECONALL}/mri/aseg.mgz --min 1 --o ${OUTDIR}/${PREFIX}_brainmask.nii.gz --dilate 1
mri_mask ${RECONALL}/mri/nu.mgz ${OUTDIR}/${PREFIX}_brainmask.nii.gz ${OUTDIR}/${PREFIX}_brain.nii.gz
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_wmmask.nii.gz --all-wm
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_csfmask.nii.gz --ventricles
# parcellation masks
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_gmmask.nii.gz --gm
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_asegmask.nii.gz --subcort-gm
mri_convert ${RECONALL}/mri/aparc+aseg.mgz ${OUTDIR}/aparc+aseg.nii.gz
3dcalc -a ${OUTDIR}/aparc+aseg.nii.gz -b ${OUTDIR}/${PREFIX}_gmmask.nii.gz -c ${OUTDIR}/${PREFIX}_asegmask.nii.gz -expr 'a*step(mod(a*step(a*b-999),1000))+a*c' -prefix ${OUTDIR}/${PREFIX}_DKAseg.nii.gz

## plot the edge of mask on bias-corrected T1 image
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_brainmask -e 2 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_wmmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_wmmask -e 2 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_csfmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_csfmask -e 2 -f 1
# DK atlas
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_DKAseg.nii.gz -c ${OUTDIR} -d ${PREFIX}_DKAseg -e 2 -f 1

## remove temporary files
rm ${OUTDIR}/aparc+aseg.nii.gz ${OUTDIR}/${PREFIX}_gmmask.nii.gz ${OUTDIR}/${PREFIX}_asegmask.nii.gz

