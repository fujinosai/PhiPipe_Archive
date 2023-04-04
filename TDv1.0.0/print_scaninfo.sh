#! /bin/bash

## print out directory and slice information into a text file
## written by Alex / 2019-01-16 / free_learner@163.com
## revised by Alex / 2020-04-24 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` print out directory and slice information into a text file

Usage example:

bash $0 -a /home/alex/data/sub001 -b /home/alex/data/sub001/scaninfo.txt

Required arguments:

        -a:  directory containing all the scanning folders
        -b:  output 

Optional arguments
  
        -c:  has sub-directory
        -d:  suffix
        -e:  overwrite

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 2 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## input directory
             INPUT=$OPTARG
             ;;
          b) ## output file
             OUTPUT=$OPTARG
             ;;
          c) ## has subdirectory
             SUBDIR=$OPTARG
             ;;
          d) ## suffix
             SUFFIX=$OPTARG
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

## get input/output directory and basename
INPUTBASE=$(basename ${INPUT})
OUTPUTDIR=$(dirname ${OUTPUT})
mkdir -p ${OUTPUTDIR}

## if has subdirectory
if [[ -z ${SUBDIR} ]]
then
    cd ${INPUT}
else
    cd ${INPUT}/*/
fi

## get the scan directory infomation
if [[ ! -f ${OUTPUT} ]]
then
    echo DIRNAME:${INPUTBASE} >> ${OUTPUT}
    for DIR in $(ls)
    do
        SLICE=$(ls ./${DIR}/*${SUFFIX} | wc -l)
        echo ${DIR}:${SLICE} >> ${OUTPUT}
    done
elif [[ ! -z ${OVERWRITE} ]]
then
    rm ${OUTPUT}
    echo DIRNAME:${INPUTBASE} >> ${OUTPUT}
    for DIR in $(ls)
    do
        SLICE=$(ls ./${DIR}/*${SUFFIX} | wc -l)
        echo ${DIR}:${SLICE} >> ${OUTPUT}
    done  
else
    echo "WARNING: ${OUTPUT} already exists, please check!!! " 
fi
