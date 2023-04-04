#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org
 
## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------------------------
`basename $0` applies transformations to images using ANTs registration files
---------------------------------------------------------------------------------
Usage example:

bash $0 -a 3 
        -b /home/alex/input/rest.nii.gz 
        -c /home/alex/output/rest_mni.nii.gz 
        -d ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz 
        -e /home/alex/input/t12mni_warp.nii.gz 
        -e /home/alex/input/t12mni0GenericAffine.mat 
        -e /home/alex/input/rest2t1GenericAffine.mat 
        -f Linear
---------------------------------------------------------------------------------
Required arguments:
        -a:  image type (0: scalar, 3: time series)
        -b:  image to be transfromed
        -c:  output
        -d:  reference space as the target
        -e:  linear and nonlinear transformation files

Optional arguments:
        -f:  interpolation method (default: Linear)
---------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 10 ]]
then
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

## if PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]
then
    echo "Please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if INPUT file/OUTPUT folder exist?
## deal with multiple transformation files
for i in "${TARRAY[@]}"
do
    ## when use inverse affine registration file, the format is [affine_matrix, 1]
    TFILE=$(echo $i | sed s/\\[//g | sed s/,1]//g)
    CMD="${CMD} -a ${TFILE}"
done
bash ${PhiPipe}/check_inout.sh -a ${INPUT} -a ${REFERENCE} ${CMD}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## interpolation method?
if [[ -z ${INTERPOLATION} ]]
then
   INTERPOLATION=Linear
fi

## apply transformations
## deal with multiple transformation files
for i in "${TARRAY[@]}"
do
    CMD02="${CMD02} -t ${i}"
done
antsApplyTransforms -e ${IMAGETYPE} -d 3 -i ${INPUT} -o ${OUTPUT} -n ${INTERPOLATION} -r ${REFERENCE} ${CMD02}

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTPUT}
if [[ $? -eq 1 ]]
then
    exit 1
fi

