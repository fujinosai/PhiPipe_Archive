#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------
`basename $0` performs FreeSurfer recon-all pipeline
---------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/t1.nii.gz
        -b /home/alex/output
        -c freesurfer
        -d /home/alex/input/t1_brainmask.nii.gz 
---------------------------------------------------------------
Required arguments:
        -a: T1-weighted raw image 
        -b: output directory
        -c: output prefix

Optional arguments:
        -d: T1 brain mask from other softwares or manual edits
---------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:" OPT
    do
      case $OPT in
          a) ## T1 input file
             T1IMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## T1 brain mask
             T1BRAINMASK=$OPTARG
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
if [[ ! -z ${T1BRAINMASK} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${T1IMAGE} -a ${T1BRAINMASK} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${T1IMAGE} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## recon-all pipeline
export SUBJECTS_DIR=${OUTDIR}
SUBJECT=${PREFIX}
## It may be tempting to denoise the T1 image before the recon-all pipeline. However, this operation may bias the surface reconstruction, according to the FreeSurfer's developers. In v7.1, ANTs' denoising was used to create initial surface. See: https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/msg67423.html
if [[ ! -z ${T1BRAINMASK} ]]
then
     recon-all -i ${T1IMAGE} -s ${SUBJECT} -autorecon1 -noskullstrip
     ## based on my experience, FreeSurfer's skull stripping is not good at dealing with dura and tend to perform badly in elderly subjects.
     ## the brain mask provided by other software is assumed in the original space, which is different from the FreeSurfer's conformed space, so first transform the brain mask file into conformed space
     ## there are several ways to transfer the brain mask file to match the dimension of T1.mgz, but the results are somewhat different and I don't know why: for instance, (1) use "mri_convert --conform"; (2) use "mri_convert -rl" (3) use "mri_vol2vol --regheader". These three methods were found in the FreeSurfer's mailing list:
     ## https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/msg16677.html
     ## https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/msg33463.html
     ## https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/msg11238.html 
     ## in v6.0.0, the mri_mask will automatically resize the brain mask file, the result of which is the same as the third way above. However, this behavior is unexpected so I explicitly resize the mask file
     ## I choose to use the first method above here, because the result seems slightly loose, although the cause is unknown.
     mri_convert ${T1BRAINMASK} ${SUBJECTS_DIR}/${SUBJECT}/mytmp_brainmask.mgz --conform
     mri_mask ${SUBJECTS_DIR}/${SUBJECT}/mri/T1.mgz ${SUBJECTS_DIR}/${SUBJECT}/mytmp_brainmask.mgz ${SUBJECTS_DIR}/${SUBJECT}/mri/brainmask.mgz
     rm ${SUBJECTS_DIR}/${SUBJECT}/mytmp_brainmask.mgz
     recon-all -s ${SUBJECT} -autorecon2 -autorecon3
else
     recon-all -i ${T1IMAGE} -s ${SUBJECT} -autorecon-all
fi

## remove redundent link
rm ${SUBJECTS_DIR}/fsaverage

## check whether recon-all finished successfully
N=$(tail ${SUBJECTS_DIR}/${SUBJECT}/scripts/recon-all.log | grep "freesurfer finished without error" | wc -l)
if [[ $N -ne 1 ]]
then
    echo "FreeSurfer recon-all failed. Please check !!!"
    exit 1
fi

