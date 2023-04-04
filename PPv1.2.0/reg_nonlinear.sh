#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
------------------------------------------------------------------------
`basename $0` performs non-linearly registration using ANTs
------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/t1_brain.nii.gz 
        -b ${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz
        -c /home/alex/output/reg
        -d t12mni
        -e ${FSLDIR}/data/standard/MNI152_T1_1mm_brain_mask_dil.nii.gz
        -f 8
------------------------------------------------------------------------
Required arguments:
        -a:  moving image to be warped
        -b:  fixed image as the target
        -c:  output directory
        -d:  output prefix

Optional arguments:
        -e:  registration mask to speed up registration
        -f:  number of cpu cores to be used
-----------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 8 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## moving image file
             MOVIMAGE=$OPTARG
             ;;
          b) ## fixed image file
             FIXIMAGE=$OPTARG
             ;;
          c) ## output directory
             OUTDIR=$OPTARG
             ;;
          d) ## output prefix
             PREFIX=$OPTARG
             ;;
          e) ## mask
             REGMASK=$OPTARG
             ;;
          f) ## number of cpu cores
             NCORE=$OPTARG
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
if [[ ! -z ${REGMASK} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${MOVIMAGE} -a ${FIXIMAGE} -a ${REGMASK} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${MOVIMAGE} -a ${FIXIMAGE} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## number of cpu cores used
if [[ -z ${NCORE} ]]
then
    NCORE=1
fi

## whether a registration mask provided
if [[ -z ${REGMASK} ]]
then
    bash ${ANTSPATH}/antsRegistrationSyN.sh -d 3 -n ${NCORE} -f ${FIXIMAGE} -t s -m ${MOVIMAGE} -o ${OUTDIR}/${PREFIX}
else
    bash ${ANTSPATH}/antsRegistrationSyN.sh -d 3 -n ${NCORE} -f ${FIXIMAGE} -t s -m ${MOVIMAGE} -o ${OUTDIR}/${PREFIX} -x ${REGMASK}
fi

## rename registration output for simplicity
mv ${OUTDIR}/${PREFIX}0GenericAffine.mat ${OUTDIR}/${PREFIX}.mat
mv ${OUTDIR}/${PREFIX}1Warp.nii.gz ${OUTDIR}/${PREFIX}_warp.nii.gz
mv ${OUTDIR}/${PREFIX}Warped.nii.gz ${OUTDIR}/${PREFIX}_warped.nii.gz
mv ${OUTDIR}/${PREFIX}1InverseWarp.nii.gz ${OUTDIR}/${PREFIX}_inversewarp.nii.gz
mv ${OUTDIR}/${PREFIX}InverseWarped.nii.gz ${OUTDIR}/${PREFIX}_inversewarped.nii.gz

## plot for check registration quality
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_warped.nii.gz -b ${FIXIMAGE} -c ${OUTDIR} -d ${PREFIX} -e 1 -f 1

## check the existence of output files
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.mat -a ${OUTDIR}/${PREFIX}_warp.nii.gz -a ${OUTDIR}/${PREFIX}_inversewarp.nii.gz -a ${OUTDIR}/${PREFIX}_warped.nii.gz -a ${OUTDIR}/${PREFIX}_inversewarped.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
