#! /bin/bash
## test the pipeline
## written by Alex / 2020-04-07 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` test processing pipelines

Usage example:

bash $0 -a /home/alex/data/t1.nii.gz 
        -b /home/alex/data/rest.nii.gz
        -c /home/alex/data/dwi.nii.gz
        -d /home/alex/data/bval
        -e /home/alex/data/bvec
        -f 2
        -g 0
        -h 2
        -i 0
        -j 1

Required arguments:

        -a:  t1 image

Optional arguments:

        -b:  bold image
        -c:  dwi image
        -d:  b-value
        -e:  b-vector
        -f:  repetition time
        -g:  slice acquisition type
        -h:  phase encoding direction
        -i:  do probabilistic tractography (Yes/No:1/0) 
        -j:  pipeline (111/222/333/444:t1/t1+bold/t1+dwi/online)
        
USAGE
    exit 1
}

if [[ $# -lt 1 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:i:j:" OPT
    do
      case $OPT in
          a) ## T1-weighted image
             T1IMAGE=$OPTARG
             ;;
          b) ## BOLD image
             BOLDIMAGE=$OPTARG
             ;;
          c) ## DWI image
             DWIIMAGE=$OPTARG
             ;;
          d) ## BVAL
             BVAL=$OPTARG
             ;;
          e) ## BVEC
             BVEC=$OPTARG
             ;;          
          f) ## Repetition time
             TR=$OPTARG
             ;;
          g) ## Slice acquisition type
             STTYPE=$OPTARG
             ;;
          h) ## Phase encoding direction
             PEDIR=$OPTARG
             ;;
          i) ## DO Probtractx
             DOPT=$OPTARG
             ;;
          j) ## Pipe
             PIPE=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## t1 pipeline
if [[ $PIPE -eq 111 ]]
then
   bash ${PhiPipe}/t1_process.sh -a ${T1IMAGE}
fi

## t1+bold pipeline
if [[ $PIPE -eq 222 ]]
then
   bash ${PhiPipe}/t1bold_process.sh -a ${T1IMAGE} -b ${BOLDIMAGE} -g 5 -i ${TR} -j ${STTYPE} -k 0.01 -l 0.1
fi

## t1+dwi pipeline
if [[ $PIPE -eq 333 ]]
then
   bash ${PhiPipe}/t1dwi_process.sh -a ${T1IMAGE} -b ${DWIIMAGE} -g ${BVAL} -h ${BVEC} -i ${PEDIR} -k ${DOPT} 
fi

## online pipeline
if [[ $PIPE -eq 444 ]]
then
   bash ${PhiPipe}/online_process.sh -a ${PhiPipe} -b ${T1IMAGE} -c ${BOLDIMAGE} -d ${TR} -e ${STTYPE} -f ${DWIIMAGE} -g ${BVAL} -h ${BVEC} -i ${PEDIR} -j ${DOPT} -k test -l s01
fi

## PHI cluster
if [[ $PIPE -eq 555 ]]
then
   qsub -cwd -V -q all.q -S /bin/bash ${PhiPipe}/online_process.sh -a ${PhiPipe} -b ${T1IMAGE} -c ${BOLDIMAGE} -d ${TR} -e ${STTYPE} -f ${DWIIMAGE} -g ${BVAL} -h ${BVEC} -i ${PEDIR} -j ${DOPT} -k test -l s01
fi

## SMHC cluster
if [[ $PIPE -eq 666 ]]
then
   qsub -l mem_free=10G,h_vmem=10G,h_fsize=10G -cwd -V -q all.q -S /bin/bash ${PhiPipe}/online_process.sh -a ${PhiPipe} -b ${T1IMAGE} -c ${BOLDIMAGE} -d ${TR} -e ${STTYPE} -f ${DWIIMAGE} -g ${BVAL} -h ${BVEC} -i ${PEDIR} -j ${DOPT} -k test -l s01
fi

