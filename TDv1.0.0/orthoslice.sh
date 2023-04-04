#! /bin/bash

## make orthogonal slices of nifti files in a directory
## written by Alex / 2019-02-15 / free_learner@163.com
## revised by Alex / 2020-04-24 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` make orthogonal slices of nifti files in a directory

Usage example:

bash $0 -a /home/alex/data/sub001 -b /home/alex/data/sub001/slices

Required arguments:

        -a:  input directory containing nifti images
        -b:  output filename

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
          b) ## output filename
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

## orthogonal slices
OUTPUTDIR=$(dirname ${OUTPUT})
for NIIDATA in $(ls ${INPUT}/*.nii*)
do
   ## get the filename
   INPUTBASE=$(basename ${NIIDATA} | xargs remove_ext)
   ## 4D data?
   NVOL=$(fslnvols ${NIIDATA})
   if [[ $NVOL -eq 1 ]]
   then
       slicer ${NIIDATA} -c -u -a ${OUTPUTDIR}/tmp_${INPUTBASE}.png
   else
       fslmaths ${NIIDATA} -Tmean ${OUTPUTDIR}/tmp_mean.nii.gz
       slicer ${OUTPUTDIR}/tmp_mean.nii.gz -c -u -a ${OUTPUTDIR}/tmp_${INPUTBASE}.png
   fi
done
convert ${OUTPUTDIR}/tmp_*.png -append ${OUTPUT}.png
rm ${OUTPUTDIR}/tmp_*
