#! /bin/bash

## processing pipeline for T1 image
## written by Alex / 2019-02-15 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-25 / free_learner@163.com
## revised by Alex / 2019-06-28 / free_learner@163.com
## revised by Alex / 2019-09-13 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` processes T1 image

Usage example:

bash $0 -a /home/alex/data/t1.nii.gz 
        -b /home/alex/data/t1_proc
        -c t1

Required arguments:

        -a:  t1 image

Optional arguments:

        -b:  t1 output directory (default: t1_proc in the input folder)
        -c:  t1 output prefix (default: t1)
        -d:  t1 brain mask  

USAGE
    exit 1
}

if [[ $# -lt 1 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:" OPT
    do
      case $OPT in
          a) ## T1-weighted image
             T1IMAGE=$OPTARG
             ;;
          b) ## T1 output directory
             T1OUTDIR=$OPTARG
             ;;
          c) ## T1 output prefix
             T1PREFIX=$OPTARG
             ;;
          d) ## t1 brain mask
             T1BRAINMASK=${OPTARG}
             ;; 
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]; then
  echo please set the \$PhiPipe environment variable
  exit
fi

## custom output directory
if [[ -z ${T1OUTDIR} ]]
then
   T1INDIR=$(dirname ${T1IMAGE})
   T1OUTDIR=${T1INDIR}/t1_proc
fi
mkdir -p ${T1OUTDIR}

## custom output prefix?
if [[ -z ${T1PREFIX} ]]
then
    T1PREFIX=t1
fi

## log directory
T1LOGDIR=${T1OUTDIR}/log
mkdir -p ${T1LOGDIR}
cat ${PhiPipe}/VERSION | sed -n 1p >> ${T1LOGDIR}/${T1PREFIX}_cmd.log

################ T1 Preprocessing ##################
## (1) freesurfer pipeline
if [[ ! -f ${T1OUTDIR}/freesurfer/scripts/recon-all.done ]]
then
 (set -x
   if [[ -z ${T1BRAINMASK} ]]
   then
       bash ${PhiPipe}/t1_freesurfer.sh -a ${T1IMAGE} -b ${T1OUTDIR} -c freesurfer
   else
       bash ${PhiPipe}/t1_freesurfer.sh -a ${T1IMAGE} -b ${T1OUTDIR} -c freesurfer -d ${T1BRAINMASK}
   fi
 )  >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
fi

## (2) make masks and visual check
if [[ ! -f ${T1OUTDIR}/masks/${T1PREFIX}_brainmask.png ]]
then
     (set -x
        mkdir -p ${T1OUTDIR}/masks
        bash ${PhiPipe}/t1_mask.sh -a ${T1OUTDIR}/freesurfer -b ${T1OUTDIR}/masks -c ${T1PREFIX}
     ) >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
fi

## (3) extract morphological measures
if [[ ! -f ${T1OUTDIR}/stats/DK_lh_thickness.txt ]]
then
     (set -x
        mkdir -p ${T1OUTDIR}/stats
        bash ${PhiPipe}/t1_stats.sh -a ${T1OUTDIR}/freesurfer -b ${T1OUTDIR}/stats
     ) >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
fi
