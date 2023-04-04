#! /bin/bash

## processing pipeline for t1 and bold fMRI images
## written by Alex / 2019-01-09 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-28 / free_learner@163.com
## revised by Alex / 2019-09-13 / free_learner@163.com
## revised by Alex / 2020-04-02 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` processes t1 and bold fMRI images

Usage example:

bash $0 -a /home/alex/data/t1.nii.gz 
        -b /home/alex/data/bold.nii.gz
        -c /home/alex/data/t1_proc
        -d /home/alex/data/bold_proc
        -e t1 
        -f bold
        -g 5 
        -h /home/alex/data/bold_ref.nii.gz 
        -i 2 
        -j 0 
        -k 0.01 
        -l 0.1 
        -m /home/alex/data/t1_brainmask.nii.gz

Required arguments:

        -a:  t1 image
        -b:  bold fMRI image

Optional arguments:

        -c:  t1 output directory (default: t1_proc in input data folder)
        -d:  bold output directory (default: bold_proc in input data folder)
        -e:  t1 output prefix (default: t1)
        -f:  bold output prefix (default: bold)
        -g:  number of dummy scans to be removed (default:0)
        -h:  bold reference file
        -i:  repetition time (default: retrieve from header)
        -j:  slice timing type (default: no slice timing)
        -k:  high pass frequency (default: no high pass)
        -l:  low pass frequency  (default: no low pass)
        -m:  t1 brain mask

Slice timing type:

        0: skip slice timing for multi-band acquisition
        1: seqplus (1 2 3 ...)
        2: seqminus (... 3 2 1)
        3: altplus (1 3 5 ... 2 4 6 ...)
        4: altplus2 (2 4 6 ... 1 3 5 ...)
        5: altminus (n n-2 n-4 ... n-1 n-3 n-5 ...)
        6: altminus2 (n-1 n-3 n-5 ... n n-2 n-4)

USAGE
    exit 1
}

if [[ $# -lt 2 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:" OPT
    do
      case $OPT in
          a) ## T1-weighted image
             T1IMAGE=$OPTARG
             ;;
          b) ## Bold fMRI image
             BOLDIMAGE=$OPTARG
             ;;
          c) ## T1 output directory
             T1OUTDIR=$OPTARG
             ;;
          d) ## Bold output directory
             BOLDOUTDIR=$OPTARG
             ;;
          e) ## T1 output prefix
             T1PREFIX=$OPTARG
             ;;
          f) ## BOLD output prefix
             BOLDPREFIX=$OPTARG
             ;;
          g) ## Number of dummy scans
             DVOL=$OPTARG
             ;;
          h) ## bold reference file
             BOLDREF=$OPTARG
             ;;
          i) ## repetition time
             TR=$OPTARG
             ;;
          j) ## slice timing type
             STTYPE=${OPTARG}
             ;;
          k) ## high pass frequency
             FBOT=$OPTARG
             ;;
          l) ## low pass frequency
             FTOP=${OPTARG}
             ;;
          m) ## t1 brain mask
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

if [[ -z ${BOLDOUTDIR} ]]
then
   BOLDINDIR=$(dirname ${BOLDIMAGE})
   BOLDOUTDIR=${BOLDINDIR}/bold_proc
fi
mkdir -p ${BOLDOUTDIR}

## custom output prefix?
if [[ -z ${T1PREFIX} ]]
then
    T1PREFIX=t1
fi
if [[ -z ${BOLDPREFIX} ]]
then
    BOLDPREFIX=bold
fi

## log directory
T1LOGDIR=${T1OUTDIR}/log
mkdir -p ${T1LOGDIR}
cat ${PhiPipe}/VERSION | sed -n 1p >> ${T1LOGDIR}/${T1PREFIX}_cmd.log

BOLDLOGDIR=${BOLDOUTDIR}/log
mkdir -p ${BOLDLOGDIR}
cat ${PhiPipe}/VERSION | sed -n 1p >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log

## predefined atlases
MNI3mm=${PhiPipe}/atlases/MNI152_T1_3mm_brain.nii.gz

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

############### BOLD Processing####################
## (1) motion correction
if [[ ! -f ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.par ]]
then
       if [[ -z ${DVOL} ]]
       then
            DVOL=0
       fi
     (set -x
       mkdir -p ${BOLDOUTDIR}/motion
       if [[ -z ${BOLDREF} ]]
       then
            bash ${PhiPipe}/bold_motion.sh -a ${BOLDIMAGE} -b ${BOLDOUTDIR}/motion -c ${BOLDPREFIX} -e ${DVOL} -f 0.5
       else
            bash ${PhiPipe}/bold_motion.sh -a ${BOLDIMAGE} -b ${BOLDOUTDIR}/motion -c ${BOLDPREFIX} -d ${BOLDREF} -e ${DVOL} -f 0.5
       fi
     ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi

## (2) slice timing
if [[ ! -f ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz ]]
then
      if [[ -z ${TR} ]]
      then
          TR=$(fslval ${BOLDIMAGE} pixdim4)
      fi
      if [[ -z ${STTYPE} ]]
      then
          STTYPE=0
      fi
    (set -x
      mkdir -p ${BOLDOUTDIR}/native
      bash ${PhiPipe}/bold_slicetime.sh -a ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.nii.gz -b ${BOLDOUTDIR}/native -c ${BOLDPREFIX}_st -d ${TR} -e ${STTYPE}
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi

## (3) BOLD to T1 BBR registration
if [[ ! -f ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat ]]
then
    (set -x
        mkdir -p ${BOLDOUTDIR}/reg
        bash ${PhiPipe}/reg_bbr.sh -a ${BOLDOUTDIR}/motion/${BOLDPREFIX}_ref.nii.gz \
                                   -b ${T1OUTDIR}/freesurfer \
                                   -c ${BOLDOUTDIR}/reg \
                                   -d ${BOLDPREFIX}2${T1PREFIX} \
                                   -e ${T1OUTDIR}/masks/${T1PREFIX}_brain.nii.gz
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi

## (4) make bold masks
if [[ ! -f ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz ]]
then
    (set -x
       mkdir -p ${BOLDOUTDIR}/masks
       bash ${PhiPipe}/bold_mask.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                             -b ${BOLDOUTDIR}/masks \
                             -c ${BOLDPREFIX} \
                             -d ${T1OUTDIR}/masks/${T1PREFIX}_brainmask.nii.gz \
                             -e ${T1OUTDIR}/masks/${T1PREFIX}_wmmask.nii.gz \
                             -f ${T1OUTDIR}/masks/${T1PREFIX}_csfmask.nii.gz \
                             -g ${T1OUTDIR}/masks/${T1PREFIX}_DKAseg.nii.gz \
                             -h ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat \
                             -i ${BOLDOUTDIR}/motion/${BOLDPREFIX}_ref.nii.gz
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi

## (5) nuisance regression
if [[ ! -f ${BOLDOUTDIR}/native/${BOLDPREFIX}_res.nii.gz ]]
then
       if [[ -z ${FBOT} ]]
       then
           FBOT=0
       fi
       if [[ -z ${FTOP} ]]
       then
           FTOP=99999
       fi
    (set -x
         bash ${PhiPipe}/bold_nuisance.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_res \
                                    -d ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.model \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_wmmean.txt \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_csfmean.txt \
                                    -e ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.censor  \
                                    -f ${FBOT} -g ${FTOP} \
                                    -h ${TR}  \
                                    -i ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
         # non-filtering for fALFF calculation
         if [[ $(echo "${FBOT} == 0" | bc ) -eq 1 ]] && [[ $(echo "${FTOP} == 99999" | bc) -eq 1 ]]
         then
            cd ${BOLDOUTDIR}/native
            ln -s ${BOLDPREFIX}_res.nii.gz ${BOLDOUTDIR}/native/${BOLDPREFIX}_nonfilt.nii.gz
         else
            bash ${PhiPipe}/bold_nuisance.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_nonfilt \
                                    -d ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.model \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_wmmean.txt \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_csfmean.txt \
                                    -e ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.censor  \
                                    -h ${TR}  \
                                    -i ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz            
         fi
      ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi

## (6) grand mean scaling and transformed into standard space
if [[ ! -f ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz ]]
then
     (set -x
         bash ${PhiPipe}/bold_gms.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_res.nii.gz \
                            -b ${BOLDOUTDIR}/native \
                            -c ${BOLDPREFIX}_gms \
                            -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
         mkdir -p ${BOLDOUTDIR}/mni
         bash ${PhiPipe}/apply_transform.sh -a 3 \
              -b ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz \
              -c ${BOLDOUTDIR}/mni/${BOLDPREFIX}_std.nii.gz \
              -d ${MNI3mm} \
              -e ${T1OUTDIR}/reg/${T1PREFIX}2mni_warp.nii.gz \
              -e ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat \
              -e ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat \
              -f Linear
         3dTstat -mean -prefix ${BOLDOUTDIR}/mni/${BOLDPREFIX}_stdmean.nii.gz ${BOLDOUTDIR}/mni/${BOLDPREFIX}_std.nii.gz
         bash ${PhiPipe}/plot_overlay.sh -a ${BOLDOUTDIR}/mni/${BOLDPREFIX}_stdmean.nii.gz -b ${MNI3mm} -c ${BOLDOUTDIR}/mni -d ${BOLDPREFIX}2mni -e 1
         rm ${BOLDOUTDIR}/mni/${BOLDPREFIX}_stdmean.nii.gz
     ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi
############### BOLD Feature Extraction ####################
## (1) computing roi correlation matrix
if [[ ! -f ${BOLDOUTDIR}/stats/roicc/${BOLDPREFIX}_DKAseg.roicc ]]
then
     (set -x
       mkdir -p ${BOLDOUTDIR}/stats/roicc
       bash ${PhiPipe}/bold_roicc.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz \
                                     -b ${BOLDOUTDIR}/stats/roicc \
                                     -c ${BOLDPREFIX}_DKAseg \
                                     -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_DKAseg.nii.gz \
                                     -e ${PhiPipe}/atlases/DKAseg_labels.txt
     ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi
## (2) computing ReHo
if [[ ! -f ${BOLDOUTDIR}/mni/${BOLDPREFIX}_stdreho.nii.gz ]]
then
    (set -x
       mkdir -p ${BOLDOUTDIR}/stats/reho
       bash ${PhiPipe}/bold_reho.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_reho \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz 
       bash ${PhiPipe}/apply_transform.sh -a 0 \
                                    -b ${BOLDOUTDIR}/native/${BOLDPREFIX}_reho.nii.gz \
                                    -c ${BOLDOUTDIR}/mni/${BOLDPREFIX}_stdreho.nii.gz \
                                    -d ${MNI3mm} \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni_warp.nii.gz \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat \
                                    -e ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat \
                                    -f Linear
       bash ${PhiPipe}/roi_stats.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_reho.nii.gz \
                                    -b ${BOLDOUTDIR}/stats/reho \
                                    -c ${BOLDPREFIX}_DKAseg_reho \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_DKAseg.nii.gz \
                                    -e ${PhiPipe}/atlases/DKAseg_labels.txt       
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
   fi
## (3) calculating ALFF/fALFF
if [[ ! -f ${BOLDOUTDIR}/mni/${BOLDPREFIX}_stdalff.nii.gz ]]
then
    (set -x
       mkdir -p ${BOLDOUTDIR}/stats/alff
       bash ${PhiPipe}/bold_alff.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_nonfilt.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX} \
                                    -d ${FBOT} -e ${FTOP} -f ${TR} \
                                    -g ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
       for meas in alff falff
       do      
          bash ${PhiPipe}/apply_transform.sh -a 0 \
                                    -b ${BOLDOUTDIR}/native/${BOLDPREFIX}_${meas}.nii.gz \
                                    -c ${BOLDOUTDIR}/mni/${BOLDPREFIX}_std${meas}.nii.gz \
                                    -d ${MNI3mm} \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni_warp.nii.gz \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat \
                                    -e ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat \
                                    -f Linear
          bash ${PhiPipe}/roi_stats.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_${meas}.nii.gz \
                                    -b ${BOLDOUTDIR}/stats/alff \
                                    -c ${BOLDPREFIX}_DKAseg_${meas} \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_DKAseg.nii.gz \
                                    -e ${PhiPipe}/atlases/DKAseg_labels.txt      
       done
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
fi
