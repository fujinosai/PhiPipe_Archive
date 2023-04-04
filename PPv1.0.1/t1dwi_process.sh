#! /bin/bash

## processing pipeline for t1 and dwi images
## written by Alex / 2019-09-10 / free_learner@163.com
## written by Alex / 2020-04-02 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` processes t1 and dwi images

Usage example:

bash $0 -a /home/alex/data/t1.nii.gz 
        -b /home/alex/data/dwi.nii.gz
        -c /home/alex/data/t1_proc
        -d /home/alex/data/dwi_proc
        -e t1 
        -f dwi
        -g /home/alex/data/bvals 
        -h /home/alex/data/bvecs
        -i 2
        -j /home/alex/data/t1_brainmask.nii.gz 
        -k 0

Required arguments:

        -a:  t1 image
        -b:  dwi image
        -g:  b-value
        -h:  b-vector
        -i:  phase encoding direction (X/Y/Z:1/2/3)

Optional arguments:

        -c:  t1 output directory (default: t1_proc in input data folder)
        -d:  dwi output directory (default: dwi_proc in input data folder)
        -e:  t1 output prefix (default: t1)
        -f:  dwi output prefix (default: dwi)
        -j:  t1 brain mask
        -k:  do probabilistic tractography

USAGE
    exit 1
}

if [[ $# -lt 5 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:i:j:k:" OPT
    do
      case $OPT in
          a) ## T1-weighted image
             T1IMAGE=$OPTARG
             ;;
          b) ## DWI image
             DWIIMAGE=$OPTARG
             ;;
          c) ## T1 output directory
             T1OUTDIR=$OPTARG
             ;;
          d) ## DWI output directory
             DWIOUTDIR=$OPTARG
             ;;
          e) ## T1 output prefix
             T1PREFIX=$OPTARG
             ;;
          f) ## DWI output prefix
             DWIPREFIX=$OPTARG
             ;;
          g) ## b-value
             BVAL=$OPTARG
             ;;
          h) ## b-vector
             BVEC=$OPTARG
             ;;
          i) ## phase encoding direction
             PEDIR=$OPTARG
             ;;
          j) ## t1 brain mask
             T1BRAINMASK=${OPTARG}
             ;;
          k) ## do probtrack
             DOPT=$OPTARG
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

if [[ -z ${DWIOUTDIR} ]]
then
   DWIINDIR=$(dirname ${DWIIMAGE})
   DWIOUTDIR=${DWIINDIR}/dwi_proc
fi
mkdir -p ${DWIOUTDIR}

## custom output prefix?
if [[ -z ${T1PREFIX} ]]
then
    T1PREFIX=t1
fi
if [[ -z ${DWIPREFIX} ]]
then
    DWIPREFIX=dwi
fi

## log directory
T1LOGDIR=${T1OUTDIR}/log
mkdir -p ${T1LOGDIR}
cat ${PhiPipe}/VERSION | sed -n 1p >> ${T1LOGDIR}/${T1PREFIX}_cmd.log

DWILOGDIR=${DWIOUTDIR}/log
mkdir -p ${DWILOGDIR}
cat ${PhiPipe}/VERSION | sed -n 1p >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log

## predefined atlases
MNI2mm=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz
JHULABEL=${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-2mm.nii.gz
JHUTRACT=${FSLDIR}/data/atlases/JHU/JHU-ICBM-tracts-maxprob-thr25-2mm.nii.gz

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

## (4) t1 to MNI152 non-linear registration
if [[ ! -f ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat ]]
then
    (set -x
      T1BRAIN=${T1OUTDIR}/masks/${T1PREFIX}_brain.nii.gz
      MNI1mm=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz
      MNIMASK=${FSLDIR}/data/standard/MNI152_T1_1mm_brain_mask_dil.nii.gz
      mkdir -p ${T1OUTDIR}/reg
      bash ${PhiPipe}/reg_nonlinear.sh -a ${T1BRAIN} -b ${MNI1mm} -c ${T1OUTDIR}/reg -d ${T1PREFIX}2mni -e ${MNIMASK}
    ) >> ${T1LOGDIR}/${T1PREFIX}_output.log 2>> ${T1LOGDIR}/${T1PREFIX}_cmd.log
fi

############### DWI Processing####################
## (1) B0 to T1 BBR registration
if [[ ! -f ${DWIOUTDIR}/reg/${DWIPREFIX}2${T1PREFIX}.mat ]]
then
    (set -x
        mkdir -p ${DWIOUTDIR}/reg
        fslroi ${DWIIMAGE} ${DWIOUTDIR}/reg/${DWIPREFIX}_b0.nii.gz 0 1
        bash ${PhiPipe}/reg_bbr.sh -a ${DWIOUTDIR}/reg/${DWIPREFIX}_b0.nii.gz \
                                   -b ${T1OUTDIR}/freesurfer \
                                   -c ${DWIOUTDIR}/reg \
                                   -d ${DWIPREFIX}2${T1PREFIX} \
                                   -e ${T1OUTDIR}/masks/${T1PREFIX}_brain.nii.gz
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
fi

## (2) make dwi masks
if [[ ! -f ${DWIOUTDIR}/masks/${DWIPREFIX}_brainmask.nii.gz ]]
then
    (set -x
       mkdir -p ${DWIOUTDIR}/masks
       bash ${PhiPipe}/dwi_mask.sh -a ${DWIOUTDIR}/reg/${DWIPREFIX}_b0.nii.gz \
                             -b ${DWIOUTDIR}/masks \
                             -c ${DWIPREFIX} \
                             -d ${T1OUTDIR}/masks/${T1PREFIX}_brainmask.nii.gz \
                             -e ${T1OUTDIR}/masks/${T1PREFIX}_DKAseg.nii.gz \
                             -f ${DWIOUTDIR}/reg/${DWIPREFIX}2${T1PREFIX}.mat \
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
fi

## (3) eddy correction
if [[ ! -f ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.nii.gz ]]
then
    (set -x
       mkdir -p ${DWIOUTDIR}/eddy
       bash ${PhiPipe}/dwi_eddy.sh -a ${DWIIMAGE} \
                             -b ${DWIOUTDIR}/eddy \
                             -c ${DWIPREFIX}_correct \
                             -d ${BVAL} \
                             -e ${BVEC} \
                             -f ${DWIOUTDIR}/masks/${DWIPREFIX}_brainmask.nii.gz \
                             -g ${PEDIR} \
                             -h 1
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
fi

## (4) diffusion tensor fitting
if [[ ! -f ${DWIOUTDIR}/dtifit/${DWIPREFIX}_FA.nii.gz ]]
then
    (set -x
       mkdir -p ${DWIOUTDIR}/dtifit
       bash ${PhiPipe}/dwi_dtifit.sh -a ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.nii.gz \
                             -b ${DWIOUTDIR}/dtifit \
                             -c ${DWIPREFIX} \
                             -d ${BVAL} \
                             -e ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.eddy_rotated_bvecs \
                             -f ${DWIOUTDIR}/masks/${DWIPREFIX}_brainmask.nii.gz
       for MEAS in FA MD AD RD
       do
         bash ${PhiPipe}/apply_transform.sh -a 0 \
                               -b ${DWIOUTDIR}/dtifit/${DWIPREFIX}_${MEAS}.nii.gz \
                               -c ${DWIOUTDIR}/dtifit/${DWIPREFIX}_std${MEAS}.nii.gz \
                               -d ${MNI2mm} \
                               -e ${T1OUTDIR}/reg/${T1PREFIX}2mni_warp.nii.gz \
                               -e ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat \
                               -e ${DWIOUTDIR}/reg/${DWIPREFIX}2${T1PREFIX}.mat \
                               -f Linear
       done
       bash ${PhiPipe}/plot_overlay.sh -a ${DWIOUTDIR}/dtifit/${DWIPREFIX}_stdFA.nii.gz -b ${MNI2mm} -c ${DWIOUTDIR}/dtifit -d fa2mni -e 1
    )  >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
fi

## (5) extract DTI metrics based on JHU atlas
if [[ ! -f ${DWIOUTDIR}/stats/dti/${DWIPREFIX}_JHUlabelFA.mean ]]
then
    (set -x
       mkdir -p ${DWIOUTDIR}/stats/dti
       for MEAS in FA MD AD RD
       do
         # JHU label atlas
         bash ${PhiPipe}/roi_stats.sh -a ${DWIOUTDIR}/dtifit/${DWIPREFIX}_std${MEAS}.nii.gz \
                                -b ${DWIOUTDIR}/stats/dti \
                                -c ${DWIPREFIX}_JHUlabel${MEAS} \
                                -d ${JHULABEL} \
                                -e ${PhiPipe}/atlases/JHUlabel_labels.txt
         # JHU tract atlas
         bash ${PhiPipe}/roi_stats.sh -a ${DWIOUTDIR}/dtifit/${DWIPREFIX}_std${MEAS}.nii.gz \
                                -b ${DWIOUTDIR}/stats/dti \
                                -c ${DWIPREFIX}_JHUtract${MEAS} \
                                -d ${JHUTRACT} \
                                -e ${PhiPipe}/atlases/JHUtract_labels.txt        
       done
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
fi

if [[ ${DOPT} -eq 1 ]]
then
## (6) fiber orientation distribution estimation
if [[ ! -f ${DWIOUTDIR}/bedpostx/merged_f1samples.nii.gz ]]
then
    (set -x
       bash ${PhiPipe}/dwi_bedpostx.sh -a ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.nii.gz \
                             -b ${DWIOUTDIR} \
                             -c bedpostx \
                             -d ${DWIOUTDIR}/masks/${DWIPREFIX}_brainmask.nii.gz \
                             -e ${BVAL} \
                             -f ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.eddy_rotated_bvecs \
                             -g 2
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
fi

## (7) probability tractography using DK+Aseg atlas
if [[ ! -f ${DWIOUTDIR}/probtrackx/DKAseg/fdt_prob.mat ]]
then
    (set -x
     mkdir -p ${DWIOUTDIR}/probtrackx
     bash ${PhiPipe}/dwi_probtrackx.sh -a ${DWIOUTDIR}/bedpostx \
                             -b ${DWIOUTDIR}/probtrackx \
                             -c DKAseg \
                             -d ${DWIOUTDIR}/masks/${DWIPREFIX}_DKAseg.nii.gz \
                             -e ${PhiPipe}/atlases/DKAseg_labels.txt
     mkdir -p ${DWIOUTDIR}/stats/probtrackx
     cp ${DWIOUTDIR}/probtrackx/DKAseg/fdt_prob.mat ${DWIOUTDIR}/stats/probtrackx/${DWIPREFIX}_DKAseg_prob.mat
     cp ${DWIOUTDIR}/probtrackx/DKAseg/DKAseg.info ${DWIOUTDIR}/stats/probtrackx/${DWIPREFIX}_DKAseg_prob.info
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
fi
fi
