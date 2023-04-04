#! /bin/bash
## test each step
## written by Alex / 2020-04-08 / free_learner@163.com

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
        -i 1

Required arguments:

        -a:  t1 image
        -b:  bold image
        -c:  dwi image
        -d:  b-value
        -e:  b-vector
        -f:  repetition time
        -g:  slice acquisition type
        -h:  phase encoding direction
        -i:  step

USAGE
    exit 1
}   

if [[ $# -lt 9 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:i:" OPT
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
          i) ## Step
             STEP=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

T1INDIR=$(dirname ${T1IMAGE})
T1OUTDIR=${T1INDIR}/t1_proc
mkdir -p ${T1OUTDIR}
RESTINDIR=$(dirname ${BOLDIMAGE})
RESTOUTDIR=${RESTINDIR}/bold_proc
mkdir -p ${RESTOUTDIR}
DWIINDIR=$(dirname ${DWIIMAGE})
DWIOUTDIR=${DWIINDIR}/dwi_proc
mkdir -p ${DWIOUTDIR}

## freesurfer pipeline
if [[ $STEP -eq 1 ]]
then
    bash ${PhiPipe}/t1_freesurfer.sh -a ${T1IMAGE} -b ${T1OUTDIR} -c freesurfer
fi

## make masks and visual check
if [[ $STEP -eq 2 ]]
then
    mkdir -p ${T1OUTDIR}/masks
    bash ${PhiPipe}/t1_mask.sh -a ${T1OUTDIR}/freesurfer -b ${T1OUTDIR}/masks -c t1
fi

## extract morphological measures
if [[ $STEP -eq 3 ]]
then
    mkdir -p ${T1OUTDIR}/stats
    bash ${PhiPipe}/t1_stats.sh -a ${T1OUTDIR}/freesurfer -b ${T1OUTDIR}/stats
fi

## t1 to MNI152 non-linear registration
if [[ $STEP -eq 4 ]]
then
   mkdir -p ${T1OUTDIR}/reg
   bash ${PhiPipe}/reg_nonlinear.sh -a ${T1OUTDIR}/masks/t1_brain.nii.gz -b ${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz -c ${T1OUTDIR}/reg -d t12mni -e ${FSLDIR}/data/standard/MNI152_T1_1mm_brain_mask_dil.nii.gz -f 4 
fi

## motion correction
if [[ $STEP -eq 5 ]]
then
   mkdir -p ${RESTOUTDIR}/motion
   bash ${PhiPipe}/bold_motion.sh -a ${BOLDIMAGE} -b ${RESTOUTDIR}/motion -c bold -e 5 -f 0.5
fi

## slice timing correction
if [[ $STEP -eq 6 ]]
then
   mkdir -p ${RESTOUTDIR}/native
   bash ${PhiPipe}/bold_slicetime.sh -a ${RESTOUTDIR}/motion/bold_mc.nii.gz -b ${RESTOUTDIR}/native -c bold_st -d ${TR} -e ${STTYPE}
fi

## bold-t1 rigid registration
if [[ $STEP -eq 7 ]]
then
   mkdir -p ${RESTOUTDIR}/reg
   bash ${PhiPipe}/reg_bbr.sh -a ${RESTOUTDIR}/motion/bold_ref.nii.gz -b ${T1OUTDIR}/freesurfer -c ${RESTOUTDIR}/reg -d bold2t1 -e ${T1OUTDIR}/masks/t1_brain.nii.gz
fi

## make masks (18 Sec)
if [[ $STEP -eq 8 ]]
then
   mkdir -p ${RESTOUTDIR}/masks
   bash ${PhiPipe}/bold_mask.sh -a ${RESTOUTDIR}/native/bold_st.nii.gz -b ${RESTOUTDIR}/masks -c bold -d ${T1OUTDIR}/masks/t1_brainmask.nii.gz -e ${T1OUTDIR}/masks/t1_wmmask.nii.gz -f ${T1OUTDIR}/masks/t1_csfmask.nii.gz -g ${T1OUTDIR}/masks/t1_DKAseg.nii.gz -h ${RESTOUTDIR}/reg/bold2t1.mat -i ${RESTOUTDIR}/motion/bold_ref.nii.gz
fi

## nuisance regression
if [[ $STEP -eq 9 ]]
then
   bash ${PhiPipe}/bold_nuisance.sh -a ${RESTOUTDIR}/native/bold_st.nii.gz -b ${RESTOUTDIR}/native -c bold_res -d ${RESTOUTDIR}/motion/bold_mc.model -d ${RESTOUTDIR}/masks/bold_wmmean.txt -d ${RESTOUTDIR}/masks/bold_csfmean.txt -e ${RESTOUTDIR}/motion/bold_mc.censor -f 0.01 -g 0.1 -h ${TR} -i ${RESTOUTDIR}/masks/bold_brainmask.nii.gz
   bash ${PhiPipe}/bold_nuisance.sh -a ${RESTOUTDIR}/native/bold_st.nii.gz -b ${RESTOUTDIR}/native -c bold_nonfilt -d ${RESTOUTDIR}/motion/bold_mc.model -d ${RESTOUTDIR}/masks/bold_wmmean.txt -d ${RESTOUTDIR}/masks/bold_csfmean.txt -e ${RESTOUTDIR}/motion/bold_mc.censor -h ${TR} -i ${RESTOUTDIR}/masks/bold_brainmask.nii.gz
fi

## grand mean scaling
if [[ $STEP -eq 10 ]]
then
   bash ${PhiPipe}/bold_gms.sh -a ${RESTOUTDIR}/native/bold_res.nii.gz -b ${RESTOUTDIR}/native -c bold_gms -d ${RESTOUTDIR}/masks/bold_brainmask.nii.gz
fi

## transform into standard space
if [[ $STEP -eq 11 ]]
then
   mkdir -p ${RESTOUTDIR}/mni
   bash ${PhiPipe}/apply_transform.sh -a 3 -b ${RESTOUTDIR}/native/bold_gms.nii.gz -c ${RESTOUTDIR}/mni/bold_std.nii.gz -d ${PhiPipe}/atlases/MNI152_T1_3mm_brain.nii.gz -e ${T1OUTDIR}/reg/t12mni_warp.nii.gz -e ${T1OUTDIR}/reg/t12mni.mat -e ${RESTOUTDIR}/reg/bold2t1.mat -f Linear
   3dTstat -mean -prefix ${RESTOUTDIR}/mni/bold_stdmean.nii.gz ${RESTOUTDIR}/mni/bold_std.nii.gz
   bash ${PhiPipe}/plot_overlay.sh -a ${RESTOUTDIR}/mni/bold_stdmean.nii.gz -b ${PhiPipe}/atlases/MNI152_T1_3mm_brain.nii.gz -c ${RESTOUTDIR}/mni -d bold2mni -e 1
   rm ${RESTOUTDIR}/mni/bold_stdmean.nii.gz 
fi

## roi-roi correlation matrix
if [[ $STEP -eq 12 ]]
then
   mkdir -p ${RESTOUTDIR}/stats/roicc
   bash ${PhiPipe}/bold_roicc.sh -a ${RESTOUTDIR}/native/bold_gms.nii.gz -b ${RESTOUTDIR}/stats/roicc -c bold_DKAseg -d ${RESTOUTDIR}/masks/bold_DKAseg.nii.gz -e ${PhiPipe}/atlases/DKAseg_labels.txt
fi

## computing ReHo
if [[ $STEP -eq 13 ]]
then
   bash ${PhiPipe}/bold_reho.sh -a ${RESTOUTDIR}/native/bold_gms.nii.gz -b ${RESTOUTDIR}/native -c bold_reho -d ${RESTOUTDIR}/masks/bold_brainmask.nii.gz 
   bash ${PhiPipe}/apply_transform.sh -a 0 -b ${RESTOUTDIR}/native/bold_reho.nii.gz -c ${RESTOUTDIR}/mni/bold_stdreho.nii.gz -d ${PhiPipe}/atlases/MNI152_T1_3mm_brain.nii.gz -e ${T1OUTDIR}/reg/t12mni_warp.nii.gz -e ${T1OUTDIR}/reg/t12mni.mat -e ${RESTOUTDIR}/reg/bold2t1.mat -f Linear
   mkdir -p ${RESTOUTDIR}/stats/reho
   bash ${PhiPipe}/roi_stats.sh -a ${RESTOUTDIR}/native/bold_reho.nii.gz -b ${RESTOUTDIR}/stats/reho -c bold_DKAseg_reho -d ${RESTOUTDIR}/masks/bold_DKAseg.nii.gz -e ${PhiPipe}/atlases/DKAseg_labels.txt
fi

## computing ALFF
if [[ $STEP -eq 14 ]]
then
   mkdir -p ${RESTOUTDIR}/stats/alff
   bash ${PhiPipe}/bold_alff.sh -a ${RESTOUTDIR}/native/bold_nonfilt.nii.gz -b ${RESTOUTDIR}/native -c bold -d 0.01 -e 0.1 -f ${TR} -g ${RESTOUTDIR}/masks/bold_brainmask.nii.gz
   for meas in alff falff
   do 
      bash ${PhiPipe}/apply_transform.sh -a 0 -b ${RESTOUTDIR}/native/bold_${meas}.nii.gz -c ${RESTOUTDIR}/mni/bold_std${meas}.nii.gz -d ${PhiPipe}/atlases/MNI152_T1_3mm_brain.nii.gz -e ${T1OUTDIR}/reg/t12mni_warp.nii.gz -e ${T1OUTDIR}/reg/t12mni.mat -e ${RESTOUTDIR}/reg/bold2t1.mat -f Linear
      bash ${PhiPipe}/roi_stats.sh -a ${RESTOUTDIR}/native/bold_${meas}.nii.gz -b ${RESTOUTDIR}/stats/alff -c bold_DKAseg_${meas} -d ${RESTOUTDIR}/masks/bold_DKAseg.nii.gz -e ${PhiPipe}/atlases/DKAseg_labels.txt
   done
fi

## b0-t1 rigid registration
if [[ $STEP -eq 15 ]]
then
   mkdir -p ${DWIOUTDIR}/reg
   fslroi ${DWIIMAGE} ${DWIOUTDIR}/reg/dwi_b0.nii.gz 0 1
   bash ${PhiPipe}/reg_bbr.sh -a ${DWIOUTDIR}/reg/dwi_b0.nii.gz -b ${T1OUTDIR}/freesurfer -c ${DWIOUTDIR}/reg -d dwi2t1 -e ${T1OUTDIR}/masks/t1_brain.nii.gz
fi

## make dwi masks
if [[ $STEP -eq 16 ]]
then
   mkdir -p ${DWIOUTDIR}/masks
   bash ${PhiPipe}/dwi_mask.sh -a ${DWIOUTDIR}/reg/dwi_b0.nii.gz -b ${DWIOUTDIR}/masks -c dwi -d ${T1OUTDIR}/masks/t1_brainmask.nii.gz -e ${T1OUTDIR}/masks/t1_DKAseg.nii.gz -f ${DWIOUTDIR}/reg/dwi2t1.mat
fi

## eddy correction
if [[ $STEP -eq 17 ]]
then
   mkdir -p ${DWIOUTDIR}/eddy
   bash ${PhiPipe}/dwi_eddy.sh -a ${DWIIMAGE} -b ${DWIOUTDIR}/eddy -c dwi_correct -d ${BVAL} -e ${BVEC} -f ${DWIOUTDIR}/masks/dwi_brainmask.nii.gz -g ${PEDIR} -h 1
fi

## diffusion tensor fitting
if [[ $STEP -eq 18 ]]
then
    mkdir -p ${DWIOUTDIR}/dtifit
    bash ${PhiPipe}/dwi_dtifit.sh -a ${DWIOUTDIR}/eddy/dwi_correct.nii.gz -b ${DWIOUTDIR}/dtifit -c dwi -d ${BVAL} -e ${DWIOUTDIR}/eddy/dwi_correct.eddy_rotated_bvecs -f ${DWIOUTDIR}/masks/dwi_brainmask.nii.gz
    for MEAS in FA MD AD RD
    do
      bash ${PhiPipe}/apply_transform.sh -a 0 -b ${DWIOUTDIR}/dtifit/dwi_${MEAS}.nii.gz -c ${DWIOUTDIR}/dtifit/dwi_std${MEAS}.nii.gz -d ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -e ${T1OUTDIR}/reg/t12mni_warp.nii.gz -e ${T1OUTDIR}/reg/t12mni.mat -e ${DWIOUTDIR}/reg/dwi2t1.mat -f Linear
    done
    bash ${PhiPipe}/plot_overlay.sh -a ${DWIOUTDIR}/dtifit/dwi_stdFA.nii.gz -b ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -c ${DWIOUTDIR}/dtifit -d fa2mni -e 1
fi

## extract DTI metrics based on JHU atlas
if [[ $STEP -eq 19 ]]
then
    mkdir -p ${DWIOUTDIR}/stats/dti
    for MEAS in FA MD AD RD
    do
      bash ${PhiPipe}/roi_stats.sh -a ${DWIOUTDIR}/dtifit/dwi_std${MEAS}.nii.gz -b ${DWIOUTDIR}/stats/dti -c dwi_JHUlabel${MEAS} -d ${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-2mm.nii.gz -e ${PhiPipe}/atlases/JHUlabel_labels.txt
      bash ${PhiPipe}/roi_stats.sh -a ${DWIOUTDIR}/dtifit/dwi_std${MEAS}.nii.gz -b ${DWIOUTDIR}/stats/dti -c dwi_JHUtract${MEAS} -d ${FSLDIR}/data/atlases/JHU/JHU-ICBM-tracts-maxprob-thr25-2mm.nii.gz -e ${PhiPipe}/atlases/JHUtract_labels.txt
    done
fi 

## bedpostx
if [[ $STEP -eq 20 ]]
then
    bash ${PhiPipe}/dwi_bedpostx.sh -a ${DWIOUTDIR}/eddy/dwi_correct.nii.gz -b ${DWIOUTDIR} -c bedpostx -d ${DWIOUTDIR}/masks/dwi_brainmask.nii.gz -e ${BVAL} -f ${DWIOUTDIR}/eddy/dwi_correct.eddy_rotated_bvecs -g 2 
fi

## probtrackx2
if [[ $STEP -eq 21 ]]
then
    mkdir -p ${DWIOUTDIR}/probtrackx
    bash ${PhiPipe}/dwi_probtrackx.sh -a ${DWIOUTDIR}/bedpostx -b ${DWIOUTDIR}/probtrackx -c DKAseg -d ${DWIOUTDIR}/masks/dwi_DKAseg.nii.gz -e ${PhiPipe}/atlases/DKAseg_labels.txt
    mkdir -p ${DWIOUTDIR}/stats/probtrackx
    cp ${DWIOUTDIR}/probtrackx/DKAseg/fdt_prob.mat ${DWIOUTDIR}/stats/probtrackx/dwi_DKAseg_prob.mat
    cp ${DWIOUTDIR}/probtrackx/DKAseg/DKAseg.info ${DWIOUTDIR}/stats/probtrackx/dwi_DKAseg.info
fi

