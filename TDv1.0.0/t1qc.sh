#! /bin/bash

## quality check of T1-weighted image using CAT12
## written by Alex / 2019-01-30 / free_learner@163.com
## revised by Alex / 2020-04-24 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` quality check of T1-weighted image

Usage example:

bash $0 -a /home/alex/data/sub001 -b /home/alex/data/sub001/qc

Required arguments:

        -a:  input directory containing T1 images (NIFTI)
        -b:  output directory containing QC results

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 2 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:" OPT
    do
      case $OPT in
          a) ## input directory
             INPUT=$OPTARG
             ;;
          b) ## output directory
             OUTPUT=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## check if input files exit
NFILE=$(ls ${INPUT}/*.nii* | wc -l)
if [[ ${NFILE} -eq 0 ]]
then
    echo "WARNING: no input files found. Please check!!!"
    exit
fi

for T1DATA in $(ls ${INPUT}/*.nii*)
do
    ## get the filename
    INPUTBASE=$(basename ${T1DATA} | xargs remove_ext)
    ## make output directory
    OUTPUTDIR=${OUTPUT}/${INPUTBASE}
    mkdir -p ${OUTPUTDIR}
    ## cp or unzip 
    if [[ -f ${INPUT}/${INPUTBASE}.nii.gz ]]
    then
         gunzip -c ${T1DATA} > ${OUTPUTDIR}/${INPUTBASE}.nii
    else
         cp ${T1DATA} ${OUTPUTDIR}/${INPUTBASE}.nii
    fi
    ## invoke cat batch script
    bash ${TIDY}/cat_batch_cat.sh ${OUTPUTDIR}/${INPUTBASE}.nii -d ${TIDY}/cat_defaults.m -p 2 -fg -l ${OUTPUTDIR} -m /data/software/matlab2015/bin/matlab
    rm ${OUTPUTDIR}/${INPUTBASE}.nii
done
