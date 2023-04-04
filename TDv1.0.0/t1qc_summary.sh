#! /bin/bash

## summary of T1 QC results
## written by Alex / 2019-02-15 / free_learner@163.com
## revised by Alex / 2020-05-07 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` summarize of T1 QC results after running t1qc.sh

Usage example:

bash $0 -a /home/alex/data/qc -b /home/alex/data/sublist.txt -c /home/alex/data/qc_results.txt

Required arguments:

        -a:  input directory containing T1 qc results
        -b:  list of subject ids
        -c:  output filename

Optional arguments:

        -d:  overwrite

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
          a) ## input directory
             INPUT=$OPTARG
             ;;
          b) ## subject list
             SUBLIST=$OPTARG
             ;;
          c) ## output filename
             OUTPUT=$OPTARG
             ;;
          d) ## overwrite
             OVERWRITE=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

if [[ ! -f ${OUTPUT} ]]
then
  ## loop through each subject
  for SUB in $(cat ${SUBLIST})
  do
       QCSCORE=0
       QCLEVEL=Z
       DIRNAME=NA
       for QCDIR in $(ls ${INPUT}/${SUB}/cat)
       do
           tmp_QCSCORE=$(cat ${INPUT}/${SUB}/cat/${QCDIR}/catlog_${QCDIR}.txt | grep "Image Quality Rating" | awk {'print $5'} | sed s/%//)
           tmp_QCLEVEL=$(cat ${INPUT}/${SUB}/cat/${QCDIR}/catlog_${QCDIR}.txt | grep "Image Quality Rating" | awk {'print $6'} | sed  s/\(// | sed s/\)//)
           if [[ $(echo "${tmp_QCSCORE} > ${QCSCORE}" | bc) -eq 1 ]]
           then
               QCLEVEL=${tmp_QCLEVEL}
               QCSCORE=${tmp_QCSCORE}
               DIRNAME=${QCDIR}
           fi
       done
       printf "%s\t%s\t%f\t%s\n" ${SUB} ${DIRNAME} ${QCSCORE} ${QCLEVEL} >> ${OUTPUT}
  done
elif [[ ! -z ${OVERWRITE} ]]
then
  rm ${OUTPUT}
  ## loop through each subject
  for SUB in $(cat ${SUBLIST})
  do
       QCSCORE=0
       QCLEVEL=Z
       DIRNAME=NA
       for QCDIR in $(ls ${INPUT}/${SUB}/cat)
       do
           tmp_QCSCORE=$(cat ${INPUT}/${SUB}/cat/${QCDIR}/catlog_${QCDIR}.txt | grep "Image Quality Rating" | awk {'print $5'} | sed s/%//)
           tmp_QCLEVEL=$(cat ${INPUT}/${SUB}/cat/${QCDIR}/catlog_${QCDIR}.txt | grep "Image Quality Rating" | awk {'print $6'} | sed  s/\(// | sed s/\)//)
           if [[ $(echo "${tmp_QCSCORE} > ${QCSCORE}" | bc) -eq 1 ]]
           then
               QCLEVEL=${tmp_QCLEVEL}
               QCSCORE=${tmp_QCSCORE}
               DIRNAME=${QCDIR}
           fi
       done
       printf "%s\t%s\t%f\t%s\n" ${SUB} ${DIRNAME} ${QCSCORE} ${QCLEVEL} >> ${OUTPUT}
  done
else
  echo "WARNING: ${OUTPUT} already exists. Please check!!!"  
fi
