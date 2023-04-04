#! /bin/bash

## convert dicom format into nifti format
## written by Alex / 2019-01-29 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` convert dicom format into nifti format

Usage example:

bash $0 -a /home/alex/data/sub001 -b MPRAGE -c /home/alex/data/t1 -d 1

Required arguments:

        -a:  directory containing all scanning data
        -b:  modality identifier
        -c:  output

Optional arguments
  
        -d:  has sub-directory
        -e:  overwrite

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 3 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## input directory
             INPUT=$OPTARG
             ;;
          b) ## modality identifier
             MODALITY=$OPTARG
             ;;
          c) ## output
             OUTPUT=$OPTARG
             ;;
          d) ## has sub-directory
             SUBDIR=$OPTARG
             ;;
          e) ## overwrite
             OVERWRITE=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## get output directory and basename
OUTPUTDIR=$(dirname ${OUTPUT})
OUTPUTBASE=$(basename ${OUTPUT})

## if has subdirectory
if [[ -z ${SUBDIR} ]]
then
    DCMDIR=${INPUT}/*${MODALITY}*
else
    DCMDIR=${INPUT}/*/*${MODALITY}*
fi

## convert dicom into nifti
if [[ ! -d ${OUTPUTDIR} ]]
then
     NDIR=$(ls -d ${DCMDIR} | wc -l)
     if [[ $NDIR -gt 0 ]]
     then
         mkdir -p ${OUTPUTDIR}
         for tmp in $(ls -d ${DCMDIR})
         do
             ${TIDY}/dcm2niix -f ${OUTPUTBASE}_%s -o ${OUTPUTDIR} -z y ${tmp}
         done
     else
         echo "WARNING: ${DCMDIR} does not exist, please check!!! "
     fi     
elif [[ ! -z ${OVERWRITE} ]]
then
     rm -r ${OUTPUTDIR}
     NDIR=$(ls -d ${DCMDIR} | wc -l)
     if [[ $NDIR -gt 0 ]]
     then
         mkdir -p ${OUTPUTDIR}
         for tmp in $(ls -d ${DCMDIR})
         do
             ${TIDY}/dcm2niix -f ${OUTPUTBASE}_%s -o ${OUTPUTDIR} -z y ${tmp}
         done
     else
         echo "WARNING: ${DCMDIR} does not exist, please check!!! "
     fi    
else
    echo "WARNING: ${OUTPUTDIR} already exists, please check!!! " 
fi

