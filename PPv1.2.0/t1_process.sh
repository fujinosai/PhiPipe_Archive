#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------------------
`basename $0` is the default processing pipeline for T1-weighted image
---------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/t1.nii.gz 
        -b /home/alex/output/t1_proc
        -c t1
---------------------------------------------------------------------------
Required arguments:
        -a:  T1 image

Optional arguments:
        -b:  T1 output directory (default: t1_proc in the input folder)
        -c:  T1 output prefix (default: t1)
        -d:  T1 brain mask (in native space) from other softwares or manual edits 
        -e:  use CAT12 for skull stripping (set 1 to turn on).
        -f:  disable T1-MNI152 registration (set 1 to turn on)
---------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 2 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:" OPT
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
          d) ## T1 brain mask
             T1BRAINMASK=${OPTARG}
             ;; 
          e) ## use CAT12 for skull stripping
             USECAT=${OPTARG}
             ;;
          f) ## disable T1-MNI registration
             NOMNIREG=${OPTARG}
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
    done
fi

## PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]
then
    echo "please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if INPUT files exist?
if [[ ! -z ${T1BRAINMASK} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${T1IMAGE} -a ${T1BRAINMASK}
else
    bash ${PhiPipe}/check_inout.sh -a ${T1IMAGE}
fi
if [[ $? -eq 1 ]]
then
    exit 1
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

## make log directory
T1LOGDIR=${T1OUTDIR}/log
mkdir -p ${T1LOGDIR}

## dashed line to segment code blocks for clarity in the log file
segline() {
 local INFO=$1
 echo "--------------------------${INFO}-----------------------------"
}

## save date and PhiPipe version information
date +"%Y-%m-%d %H:%M:%S" >> ${T1LOGDIR}/${T1PREFIX}_cmd.log 
segline "Software information" >> ${T1LOGDIR}/${T1PREFIX}_cmd.log
cat ${PhiPipe}/VERSION | sed -n 2p >> ${T1LOGDIR}/${T1PREFIX}_cmd.log

## save dependent software information (remove lines started with "-")
bash ${PhiPipe}/check_dependencies.sh | sed '/^-/d' >> ${T1LOGDIR}/${T1PREFIX}_cmd.log

## Start T1 Processing
## (1) FreeSurfer's recon-all pipeline
segline "T1 Processing:Step 1" | tee -a ${T1LOGDIR}/${T1PREFIX}_output.log >> ${T1LOGDIR}/${T1PREFIX}_cmd.log
if [[ ! -f ${T1OUTDIR}/freesurfer/scripts/recon-all.done ]]
then
    (set -x
      if [[ -f ${T1BRAINMASK} ]]
      then
          bash ${PhiPipe}/t1_freesurfer.sh -a ${T1IMAGE} -b ${T1OUTDIR} -c freesurfer -d ${T1BRAINMASK}
      elif [[ ${USECAT} -eq 1 ]]
      then
          mkdir -p ${T1OUTDIR}/cat
          bash ${PhiPipe}/t1_cat.sh -a ${T1IMAGE} -b ${T1OUTDIR}/cat -c ${T1PREFIX}
          bash ${PhiPipe}/t1_freesurfer.sh -a ${T1IMAGE} -b ${T1OUTDIR} -c freesurfer -d ${T1OUTDIR}/cat/${T1PREFIX}_brainmask.nii.gz
      else
          bash ${PhiPipe}/t1_freesurfer.sh -a ${T1IMAGE} -b ${T1OUTDIR} -c freesurfer
      fi
    )  >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "T1 Processing:Step 1 Failed!"
        exit 1
    fi
fi

## (2) parcellate the brain using non-builtin atlases
segline "T1 Processing:Step 2" | tee -a ${T1LOGDIR}/${T1PREFIX}_output.log >> ${T1LOGDIR}/${T1PREFIX}_cmd.log
if [[ ! -f ${T1OUTDIR}/freesurfer/stats/lh.Schaefer.100Parcels.7Networks.stats ]]
then
    (set -x    
         bash ${PhiPipe}/t1_parcel.sh -a ${T1OUTDIR}/freesurfer -b 1
    ) >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "T1 Processing:Step 2 Failed!"
        exit 1
    fi
fi

## (3) make masks and visual check snapshots
segline "T1 Processing:Step 3" | tee -a ${T1LOGDIR}/${T1PREFIX}_output.log >> ${T1LOGDIR}/${T1PREFIX}_cmd.log
if [[ ! -f ${T1OUTDIR}/masks/${T1PREFIX}_brainmask.png ]]
then
    (set -x
        mkdir -p ${T1OUTDIR}/masks
        bash ${PhiPipe}/t1_mask.sh -a ${T1OUTDIR}/freesurfer -b ${T1OUTDIR}/masks -c ${T1PREFIX} -d 1 -e 1
    ) >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "T1 Processing:Step 3 Failed!"
        exit 1
    fi
fi

## (4) extract parcel-wise morphological measures
segline "T1 Processing:Step 4" | tee -a ${T1LOGDIR}/${T1PREFIX}_output.log >> ${T1LOGDIR}/${T1PREFIX}_cmd.log
if [[ ! -f ${T1OUTDIR}/stats/t1_DK_thickness.mean ]]
then
    (set -x
        mkdir -p ${T1OUTDIR}/stats
        bash ${PhiPipe}/t1_stats.sh -a ${T1OUTDIR}/freesurfer -b ${T1OUTDIR}/stats -c ${T1PREFIX} -d 1 -e 1 -f 1
    ) >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "T1 Processing:Step 4 Failed!"
        exit 1
    fi
fi

## (5) T1 to MNI152 non-linear registration
if [[ ${NOMNIREG} -ne 1 ]]
then
segline "T1 Processing:Step 5" | tee -a ${T1LOGDIR}/${T1PREFIX}_output.log >> ${T1LOGDIR}/${T1PREFIX}_cmd.log
if [[ ! -f ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat ]]
then
    (set -x
      T1BRAIN=${T1OUTDIR}/masks/${T1PREFIX}_brain.nii.gz
      MNI1mm=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz
      MNIMASK=${FSLDIR}/data/standard/MNI152_T1_1mm_brain_mask_dil.nii.gz
      mkdir -p ${T1OUTDIR}/reg
      bash ${PhiPipe}/reg_nonlinear.sh -a ${T1BRAIN} -b ${MNI1mm} -c ${T1OUTDIR}/reg -d ${T1PREFIX}2mni -e ${MNIMASK}
    ) >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "T1 Processing:Step 5 Failed!"
        exit 1
    fi
fi
fi
