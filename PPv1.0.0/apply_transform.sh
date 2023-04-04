#! /bin/bash

## wrapper for ANTs' applyTransforms
## written by Alex / 2019-01-09 / free_learner@163.com
## written by Alex / 2019-06-27 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` applies transformations to images using ANTs registration files

Usage example:

bash $0 -a 3 
        -b /home/alex/data/rest.nii.gz 
        -c /home/alex/data/rest_std.nii.gz 
        -d ${FSLDIR}/data/standard/MNI152_T1_3mm_brain.nii.gz 
        -e /home/alex/data/t12mni_warp.nii.gz 
        -e /home/alex/data/t12mni0GenericAffine.mat 
        -e /home/alex/data/rest2t1GenericAffine.mat 
        -f Linear

Required arguments:

        -a:  image type (0: scalar, 3: time series)
        -b:  image to be transfromed
        -c:  output
        -d:  refence space as the target
        -e:  linear and nonlinear transformation files

Optional arguments:

        -f:  interpolation method default: Linear

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 5 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## image type
             IMAGETYPE=$OPTARG
             ;;
          b) ## input file to be transformed
             INPUT=$OPTARG
             ;;
          c) ## output
             OUTPUT=$OPTARG
             ;;
          d) ## reference file
             REFERENCE=$OPTARG
             ;;
          e) ## transformation files
             TARRAY+=("$OPTARG")
             ;;
          f) ## interpolation methods
             INTERPOLATION=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## interpolation method?
if [[ -z ${INTERPOLATION} ]]
then
   INTERPOLATION=Linear
fi

## deal with multiple transformation files
for i in "${TARRAY[@]}"
do
    CMD="${CMD} -t ${i}"
done

## apply transformations
antsApplyTransforms -e ${IMAGETYPE} -d 3 -i ${INPUT} -o ${OUTPUT} -n ${INTERPOLATION} -r ${REFERENCE} ${CMD}

