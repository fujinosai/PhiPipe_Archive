#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------------------------------
`basename $0` performs boundary-based rigid registration between T1 and BOLD fMRI images
-----------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/rest_ref.nii.gz
        -b /home/alex/input/freesurfer
        -c /homoe/alex/output
        -d rest2t1
-----------------------------------------------------------------------------------------
Required arguments:
        -a:  moving image 
        -b:  FreeSurfer recon-all directory
        -c:  output directory
        -d:  output prefix
-----------------------------------------------------------------------------------------
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
          a) ## moving image file
             MOVIMAGE=$OPTARG
             ;;
          b) ## freesurfer recon-all directory
             RECONALL=$OPTARG
             ;;
          c) ## output directory
             OUTDIR=$OPTARG
             ;;
          d) ## output prefix
             PREFIX=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -a ${MOVIMAGE} -b ${RECONALL} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## get recon-all directory and its parent directory
export SUBJECTS_DIR=$(dirname ${RECONALL})
SUBJECT=$(basename ${RECONALL})

## BBR
## bbregister will register --mov into FreeSurfer's comformed space (for instance, where orig.mgz resides)
## by default, FSL's bet will be performed if using --init-fsl (see option --fsl-bet-mov)
## in this version --init-fsl was replaced with --init-coreg (also bbregister's default option), because --init-coreg is more robust
## Reference: https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/msg52089.html
bbregister --s ${SUBJECT} --mov ${MOVIMAGE} --reg ${OUTDIR}/${PREFIX}.dat --init-coreg --t2 --fslmat ${OUTDIR}/${PREFIX}_fsl.mat --o ${OUTDIR}/${PREFIX}_warped.nii.gz
## convert FSL format into ANTs (ITK) format
## convert ANTs format into FSL format: c3d_affine_tool -ref ${FIXIMAGE} -src ${MOVIMAGE} -itk ants.mat -ras2fsl -o fsl.mat
## the orders of -ref/-src (-ref/-src/-itk) can be changed (first part); the orders of -ras2fsl/-oitk (-fsl2ras/-o) can be changed (second part); the orders of two parts can not be changed
## create white matter mask as referenc file and for quality control
## in previous version, an explicit brain image was provided. To make the script more independent from other scripts, create the reference file temporarily in the script.
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/mytmp_wmmask.nii.gz --all-wm 
c3d_affine_tool ${OUTDIR}/${PREFIX}_fsl.mat -ref ${OUTDIR}/mytmp_wmmask.nii.gz -src ${MOVIMAGE} -fsl2ras -oitk ${OUTDIR}/${PREFIX}.mat

## check registration quality
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_warped.nii.gz -b ${OUTDIR}/mytmp_wmmask.nii.gz -c ${OUTDIR} -d ${PREFIX} -e 1 -f 1

## remove temporary files
rm ${OUTDIR}/mytmp_wmmask.nii.gz

## if output files exist?
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_fsl.mat -a ${OUTDIR}/${PREFIX}.mat -a ${OUTDIR}/${PREFIX}_warped.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi

