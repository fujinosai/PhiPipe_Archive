#! /bin/bash

## boundary-based rigid registration between two images (normally inter-modal) using FreeSurfer
## written by Alex / 2019-01-08 / free_learner@163.com 
## revised by Alex / 2019-06-26 / free_learner@163.com
## revised by Alex / 2019-09-12 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` performs boundary-based rigid registration between two images (normally inter-modal) using FreeSurfer

Usage example:

bash $0 -a /home/alex/data/rest_ref.nii.gz
        -b /home/alex/data/freesurfer
        -c /homoe/alex/data
        -d rest2t1
        -e /home/alex/data/t1_brain.nii.gz

Required arguments:

        -a:  moving image 
        -b:  FreeSurfer recon-all directory
        -c:  output directory
        -d:  output prefix
        -e:  t1 brain image for reference

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 5 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:" OPT
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
          e) ## T1 brain image
             T1BRAIN=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## get recon-all directory and its parent directory
export SUBJECTS_DIR=$(dirname ${RECONALL})
SUBJECT=$(basename ${RECONALL})

## BBR
## bbregister will register --mov into orig.mgz (comformed space)
## by default, bet will be performed if using --init-fsl 
bbregister --s ${SUBJECT} --mov ${MOVIMAGE} --reg ${OUTDIR}/${PREFIX}.dat --init-fsl --t2 --fslmat ${OUTDIR}/${PREFIX}_fsl.mat --o ${OUTDIR}/${PREFIX}_warped.nii.gz
c3d_affine_tool ${OUTDIR}/${PREFIX}_fsl.mat -ref ${T1BRAIN} -src ${MOVIMAGE} -fsl2ras -oitk ${OUTDIR}/${PREFIX}.mat

## check registration quality
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_warped.nii.gz -b ${T1BRAIN} -c ${OUTDIR} -d ${PREFIX} -e 1 -f 1

