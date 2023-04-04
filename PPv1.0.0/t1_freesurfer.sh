#! /bin/bash

## wrapper for FreeSurfer's recon-all pipeline
## written by Alex / 2019-01-08 / free_learner@163.com 
## revised by Alex / 2019-06-25 / free_learner@163.com
## revised by Alex / 2019-09-12 / free_learner@163.com
## reviesed by Alex / 2020-03-31 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` performs FreeSurfer recon-all pipeline

Usage example:

bash $0 -a /home/alex/data/t1.nii.gz
        -b /home/alex/data
        -c freesurfer
        -d /home/alex/data/t1_brainmask.nii.gz 

Required arguments:

        -a: T1-weighted, MPRAGE   
        -b: output directory
        -c: output prefix

Optional arguments:

        -d: t1 brain mask from other softwares or manual edits

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
          a) ## t1 input file
             T1IMAGE=$OPTARG
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
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## recon-all pipeline
export SUBJECTS_DIR=${OUTDIR}
SUBJECT=${PREFIX}
if [[ -f ${T1BRAINMASK} ]]
then
     recon-all -i ${T1IMAGE} -s ${SUBJECT} -autorecon1 -noskullstrip
     mri_mask ${SUBJECTS_DIR}/${SUBJECT}/mri/T1.mgz ${T1BRAINMASK} ${SUBJECTS_DIR}/${SUBJECT}/mri/brainmask.mgz
     recon-all -s ${SUBJECT} -autorecon2 -autorecon3
else
     recon-all -i ${T1IMAGE} -s ${SUBJECT} -autorecon-all
fi
## remove redundent link
rm ${SUBJECTS_DIR}/fsaverage

