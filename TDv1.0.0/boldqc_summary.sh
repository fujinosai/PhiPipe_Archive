#! /bin/bash

## summary of BOLD QC results
## written by Alex / 2019-02-16 / free_learner@163.com
## revised by Alex / 2020-05-07 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` summarize of BOLD QC results after running boldqc.sh

Usage example:

bash $0 -a /home/alex/data/qc -b /home/alex/data/sublist.txt -c /home/alex/data/qc_results.txt -d 150

Required arguments:

        -a:  input directory containing BOLD qc results
        -b:  list of subject ids
        -c:  output filename
        -d:  expected time points

Optional arguments:

        -e:  overwrite

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 4 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:" OPT
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
          d) ## expected time points
             NVOL=$OPTARG
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

if [[ ! -f ${OUTPUT} ]]
then
  ## loop through each subject
  for SUB in $(cat ${SUBLIST})
  do
       MEANFD=5
       OUTRATIO=1
       DIRNAME=NA
       for QCDIR in $(ls ${INPUT}/${SUB}/motion)
       do
           tmp_NVOL=$(cat ${INPUT}/${SUB}/motion/${QCDIR}/bold_mc.metric | sed -n 1p | cut -d ':' -f2)
           tmp_MEANFD=$(cat ${INPUT}/${SUB}/motion/${QCDIR}/bold_mc.metric | sed -n 2p | cut -d ':' -f2)
           tmp_OUTRATIO=$(cat ${INPUT}/${SUB}/motion/${QCDIR}/bold_mc.metric | sed -n 3p | cut -d ':' -f2)
           if [[ $tmp_NVOL -gt $NVOL ]]  #  2020.10.21  change -eq to -gt
           then
               if [[ $(echo "${tmp_MEANFD} < ${MEANFD}" | bc) -eq 1 ]] && [[ $(echo "${tmp_OUTRATIO} < ${OUTRATIO}" | bc) -eq 1 ]]
               then
                   MEANFD=${tmp_MEANFD}
                   OUTRATIO=${tmp_OUTRATIO}
                   DIRNAME=${QCDIR}
               elif [[ $(echo "${tmp_MEANFD} < ${MEANFD}" | bc) -eq 1 ]]
               then
                   MEANFD=${tmp_MEANFD}
                   OUTRATIO=${tmp_OUTRATIO}
                   DIRNAME=${QCDIR}
                   echo "WARNING: sub-optimal selection, please check ${SUB}!!! "
               fi
           fi
       done
       printf "%s\t%s\t%f\t%s\n" ${SUB} ${DIRNAME} ${MEANFD} ${OUTRATIO} >> ${OUTPUT}
  done
elif [[ ! -z ${OVERWRITE} ]]
then
  rm ${OUTPUT}
  ## loop through each subject
  for SUB in $(cat ${SUBLIST})
  do
       MEANFD=5
       OUTRATIO=1
       DIRNAME=NA
       for QCDIR in $(ls ${INPUT}/${SUB}/motion)
       do
           tmp_NVOL=$(cat ${INPUT}/${SUB}/motion/${QCDIR}/bold_mc.metric | sed -n 1p | cut -d ':' -f2)
           tmp_MEANFD=$(cat ${INPUT}/${SUB}/motion/${QCDIR}/bold_mc.metric | sed -n 2p | cut -d ':' -f2)
           tmp_OUTRATIO=$(cat ${INPUT}/${SUB}/motion/${QCDIR}/bold_mc.metric | sed -n 3p | cut -d ':' -f2)
           if [[ $tmp_NVOL -gt $NVOL ]]  #  2020.10.21  change -eq to -gt
           then
               if [[ $(echo "${tmp_MEANFD} < ${MEANFD}" | bc) -eq 1 ]] && [[ $(echo "${tmp_OUTRATIO} < ${OUTRATIO}" | bc) -eq 1 ]]
               then
                   MEANFD=${tmp_MEANFD}
                   OUTRATIO=${tmp_OUTRATIO}
                   DIRNAME=${QCDIR}
               elif [[ $(echo "${tmp_MEANFD} < ${MEANFD}" | bc) -eq 1 ]]
               then
                   MEANFD=${tmp_MEANFD}
                   OUTRATIO=${tmp_OUTRATIO}
                   DIRNAME=${QCDIR}
                   echo "WARNING: sub-optimal selection, please check ${SUB}!!! "
               fi
           fi
       done
       printf "%s\t%s\t%f\t%s\n" ${SUB} ${DIRNAME} ${MEANFD} ${OUTRATIO} >> ${OUTPUT}
  done   
else
  echo "WARNING: ${OUTPUT} already exists. Please check!!!"  
fi
