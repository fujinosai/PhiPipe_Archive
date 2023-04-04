#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------------------------------
`basename $0` is the default processing pipeline for resting-state BOLD fMRI images
-----------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/output/t1_proc
        -b t1
        -c /home/alex/input/bold.nii.gz
        -d /home/alex/output/bold_proc
        -e bold 
        -f 5
        -g /home/alex/input/bold_ref.nii.gz 
        -h 2 
        -i 0 
        -k 0.01 
        -l 0.1 
-----------------------------------------------------------------------------------------
Required arguments:
        -a:  T1 output directory (created by t1_process.sh)
        -c:  BOLD fMRI image

Optional arguments:
        -b:  T1 output prefix (default: t1)
        -d:  BOLD output directory (default: bold_proc in input data folder)
        -e:  BOLD output prefix (default: bold)
        -f:  number of dummy scans to be removed (default: 0)
        -g:  BOLD reference file (default: median volume)
        -h:  repetition time (default: retrieve from input data header)
        -i:  slice timing type (default: no slice timing)
        -j:  custom slice timing file (for multi-band acquisition)
        -k:  high pass frequency (default: no high pass)
        -l:  low pass frequency  (default: no low pass)
        -m:  do global signal regression (default: 0, set 1 to turn on)

Slice timing type:
        0: no slice timing correction
        1: seqplus (1 2 3 ...)
        2: seqminus (... 3 2 1)
        3: altplus (1 3 5 ... 2 4 6 ...)
        4: altplus2 (2 4 6 ... 1 3 5 ...)
        5: altminus (n n-2 n-4 ... n-1 n-3 n-5 ...)
        6: altminus2 (n-1 n-3 n-5 ... n n-2 n-4)
        7: custom slice timing file
----------------------------------------------------------------------------------------
USAGE
    exit 1
}

if [[ $# -lt 4 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:" OPT
    do
      case $OPT in
          a) ## T1 output directory
             T1OUTDIR=$OPTARG
             ;;
          b) ## T1 output prefix
             T1PREFIX=$OPTARG
             ;;
          c) ## BOLD fMRI image
             BOLDIMAGE=$OPTARG
             ;;
          d) ## BOLD output directory
             BOLDOUTDIR=$OPTARG
             ;;
          e) ## BOLD output prefix
             BOLDPREFIX=$OPTARG
             ;;
          f) ## Number of dummy scans
             DVOL=$OPTARG
             ;;
          g) ## BOLD reference file
             BOLDREF=$OPTARG
             ;;
          h) ## repetition time
             TR=$OPTARG
             ;;
          i) ## slice timing type
             STTYPE=${OPTARG}
             ;;
          j) ## slice timing file
             STFILE=${OPTARG}
             ;;
          k) ## high pass frequency
             FBOT=$OPTARG
             ;;
          l) ## low pass frequency
             FTOP=${OPTARG}
             ;;
          m) ## global signal regression
             GSR=${OPTARG}
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

## if INPUT files/folders exist?
if [[ ! -z ${BOLDREF} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${BOLDREF} -b ${T1OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -b ${T1OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi
## check slice timing file
if [[ ! -z $STFILE ]]
then
    if [[ ! -f ${STFILE} ]]
    then
        echo "FILE ${STFILE} doesn't exist. Please check !!!"
        exit
    fi
fi

## custom output directory
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
BOLDLOGDIR=${BOLDOUTDIR}/log
mkdir -p ${BOLDLOGDIR}

## dashed line to segment code blocks for clarity in the log file
segline() {
 local INFO=$1
 echo "--------------------------${INFO}-----------------------------"
}

## save date and PhiPipe version information
date +"%Y-%m-%d %H:%M:%S" >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
segline "Software information" >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
cat ${PhiPipe}/VERSION | sed -n 2p >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log

## save dependent software information (remove lines started with "-")
bash ${PhiPipe}/check_dependencies.sh | sed '/^-/d' >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log

## Start BOLD Processing
## (1) Motion Correction
segline "BOLD Processing:Step 1" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
if [[ ! -f ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.matrix ]]
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
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 1 Failed!"
        exit 1
    fi
fi

## (2) Slice Timing Correction
segline "BOLD Processing:Step 2" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
if [[ ! -f ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz ]]
then
    if [[ -z ${TR} ]]
    then
        TR=$(3dinfo -tr ${BOLDIMAGE})
    fi
    if [[ -z ${STTYPE} ]]
    then
        STTYPE=0
    fi
    (set -x
      mkdir -p ${BOLDOUTDIR}/native
      if [[ $STTYPE -eq 7 ]]
      then
          if [[ ! -z ${STFILE} ]]
          then
              bash ${PhiPipe}/bold_slicetime.sh -a ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.nii.gz -b ${BOLDOUTDIR}/native \
                                                -c ${BOLDPREFIX}_st -d ${TR} -e ${STTYPE} -f ${STFILE}
          else
              echo "Slice timing file was not provided. Please check !!!"
              exit 1
          fi
      else 
          bash ${PhiPipe}/bold_slicetime.sh -a ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.nii.gz -b ${BOLDOUTDIR}/native \
                                            -c ${BOLDPREFIX}_st -d ${TR} -e ${STTYPE}
      fi
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 2 Failed!"
        exit 1
    fi
fi

## (3) BOLD to T1 BBR Registration
segline "BOLD Processing:Step 3" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
if [[ ! -f ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat ]]
then
    (set -x
        mkdir -p ${BOLDOUTDIR}/reg
        bash ${PhiPipe}/reg_bbr.sh -a ${BOLDOUTDIR}/motion/${BOLDPREFIX}_ref.nii.gz -b ${T1OUTDIR}/freesurfer \
                                   -c ${BOLDOUTDIR}/reg -d ${BOLDPREFIX}2${T1PREFIX}
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 3 Failed!"
        exit 1
    fi
fi

## (4) Make BOLD Masks
segline "BOLD Processing:Step 4" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
if [[ ! -f ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz ]]
then
    (set -x
       mkdir -p ${BOLDOUTDIR}/masks
       bash ${PhiPipe}/bold_mask.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                             -b ${BOLDOUTDIR}/masks \
                             -c ${BOLDPREFIX} \
                             -d ${T1OUTDIR}/masks/${T1PREFIX}_brainmask.nii.gz \
                             -e ${T1OUTDIR}/masks/${T1PREFIX}_gmmask.nii.gz \
                             -f ${T1OUTDIR}/masks/${T1PREFIX}_wmmask.nii.gz \
                             -g ${T1OUTDIR}/masks/${T1PREFIX}_csfmask.nii.gz \
                             -h ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.dat \
                             -i ${T1OUTDIR}/masks/${T1PREFIX}_DKAseg.nii.gz \
                             -j ${T1OUTDIR}/masks/${T1PREFIX}_SchaeferAseg.nii.gz
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 4 Failed!"
        exit 1
    fi
fi

## (5) Motion Censoring/Nuisance Regression/Temporal filtering
segline "BOLD Processing:Step 5" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
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
       if [[ -z ${GSR} ]]
       then
           GSR=0
       fi
    (set -x
         if [[ ${GSR} -eq 0 ]]
         then
             bash ${PhiPipe}/bold_nuisance.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_res \
                                    -d ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.model \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_wm.mean \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_csf.mean \
                                    -e ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.censor  \
                                    -f ${FBOT} -g ${FTOP} \
                                    -h ${TR}  \
                                    -i ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
         else
             bash ${PhiPipe}/bold_nuisance.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_res \
                                    -d ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.model \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brain.mean \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_wm.mean \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_csf.mean \
                                    -e ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.censor  \
                                    -f ${FBOT} -g ${FTOP} \
                                    -h ${TR}  \
                                    -i ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
         fi
      ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 5 Failed!"
        exit 1
    fi
fi

## (6) Grand Mean Scaling/Transformation into Standard Space (MNI)
segline "BOLD Processing:Step 6" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
MNI3mm=${PhiPipe}/templates/MNI152/MNI152_T1_3mm_brain.nii.gz
if [[ ! -f ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz ]]
then
     (set -x
         ## grand mean scaling
         bash ${PhiPipe}/bold_gms.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_res.nii.gz -b ${BOLDOUTDIR}/native \
                                     -c ${BOLDPREFIX}_gms -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
         ## spatial normalization
         mkdir -p ${BOLDOUTDIR}/mni
         bash ${PhiPipe}/reg_apply.sh -a 3 \
              -b ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz \
              -c ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mni.nii.gz \
              -d ${MNI3mm} \
              -e ${T1OUTDIR}/reg/${T1PREFIX}2mni_warp.nii.gz \
              -e ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat \
              -e ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat \
              -f Linear
         3dTstat -mean -prefix ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mean.nii.gz ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mni.nii.gz
         bash ${PhiPipe}/plot_overlay.sh -a ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mean.nii.gz -b ${MNI3mm} \
                                         -c ${BOLDOUTDIR}/mni -d ${BOLDPREFIX}2mni -e 1
         rm ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mean.nii.gz
     ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 6 Failed!"
        exit 1
    fi
fi

## (7) Computing ROI-ROI Correlation Matrix
segline "BOLD Processing:Step 7" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
if [[ ! -f ${BOLDOUTDIR}/stats/roicc/${BOLDPREFIX}_DKAseg_roicc.matrix ]]
then
     (set -x
       mkdir -p ${BOLDOUTDIR}/stats/roicc
       mkdir -p ${BOLDOUTDIR}/stats/vwroicc
       for ATLAS in DKAseg SchaeferAseg
       do
         if [[ $ATLAS == "DKAseg" ]]
         then
             LABEL=${PhiPipe}/atlases/DKAseg/DKAseg_labels.txt
         else
             LABEL=${PhiPipe}/atlases/SchaeferAseg/Schaefer.100Parcels.7Networks.Aseg_labels.txt
         fi
         ## correlation using ROI mean signals
         bash ${PhiPipe}/bold_roicc.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz \
                                     -b ${BOLDOUTDIR}/stats/roicc \
                                     -c ${BOLDPREFIX}_${ATLAS}_roicc \
                                     -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_${ATLAS}.nii.gz \
                                     -e ${LABEL}
         ## voxel-wise correlation
         bash ${PhiPipe}/bold_vwroicc.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz \
                                     -b ${BOLDOUTDIR}/stats/vwroicc \
                                     -c ${BOLDPREFIX}_${ATLAS}_vwroicc \
                                     -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_${ATLAS}.nii.gz \
                                     -e ${LABEL}         
       done
     ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 7 Failed!"
        exit 1
    fi
fi

## (8) Computing ReHo
segline "BOLD Processing:Step 8" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
if [[ ! -f ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mnireho.nii.gz ]]
then
    (set -x
       ## ReHo calculation
       bash ${PhiPipe}/bold_reho.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_gms.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_reho \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz 
       ## transform into standard space
       bash ${PhiPipe}/reg_apply.sh -a 0 \
                                    -b ${BOLDOUTDIR}/native/${BOLDPREFIX}_reho.nii.gz \
                                    -c ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mnireho.nii.gz \
                                    -d ${MNI3mm} \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni_warp.nii.gz \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat \
                                    -e ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat \
                                    -f Linear
       ## calculating ROI-wise mean
       mkdir -p ${BOLDOUTDIR}/stats/reho
       for ATLAS in DKAseg SchaeferAseg
       do
         if [[ $ATLAS == "DKAseg" ]]
         then
             LABEL=${PhiPipe}/atlases/DKAseg/DKAseg_labels.txt
         else
             LABEL=${PhiPipe}/atlases/SchaeferAseg/Schaefer.100Parcels.7Networks.Aseg_labels.txt
         fi
         bash ${PhiPipe}/roi_stats.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_reho.nii.gz \
                                    -b ${BOLDOUTDIR}/stats/reho \
                                    -c ${BOLDPREFIX}_${ATLAS}_reho \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_${ATLAS}.nii.gz \
                                    -e ${LABEL}      
       done
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 8 Failed!"
        exit 1
    fi
fi

## (9) Calculating ALFF/fALFF
## In the previous versions, the passband is set based on the temporal filtering. In this version, the passband is fixed at 0.01-0.1Hz to conform to the ALFF/fALFF original definition 
segline "BOLD Processing:Step 9" | tee -a ${BOLDLOGDIR}/${BOLDPREFIX}_output.log >> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
if [[ ! -f ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mnialff.nii.gz ]]
then
    (set -x
       ## non-filtering for ALFF/fALFF calculation
       if [[ ${GSR} -eq 0 ]]
       then
           bash ${PhiPipe}/bold_nuisance.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_nonfilt \
                                    -d ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.model \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_wm.mean \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_csf.mean \
                                    -e ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.censor  \
                                    -h ${TR}  \
                                    -i ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
       else
           bash ${PhiPipe}/bold_nuisance.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_st.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX}_nonfilt \
                                    -d ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.model \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brain.mean \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_wm.mean \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_csf.mean \
                                    -e ${BOLDOUTDIR}/motion/${BOLDPREFIX}_mc.censor  \
                                    -h ${TR}  \
                                    -i ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
       fi
       ## ALFF/fALFF calculation
       bash ${PhiPipe}/bold_alff.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_nonfilt.nii.gz \
                                    -b ${BOLDOUTDIR}/native \
                                    -c ${BOLDPREFIX} \
                                    -d 0.01 -e 0.1 -f ${TR} \
                                    -g ${BOLDOUTDIR}/masks/${BOLDPREFIX}_brainmask.nii.gz
       rm ${BOLDOUTDIR}/native/${BOLDPREFIX}_nonfilt.nii.gz
       ## transform into standard space and calculating ROI mean 
       for meas in alff falff
       do
         bash ${PhiPipe}/reg_apply.sh -a 0 \
                                    -b ${BOLDOUTDIR}/native/${BOLDPREFIX}_${meas}.nii.gz \
                                    -c ${BOLDOUTDIR}/mni/${BOLDPREFIX}_mni${meas}.nii.gz \
                                    -d ${MNI3mm} \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni_warp.nii.gz \
                                    -e ${T1OUTDIR}/reg/${T1PREFIX}2mni.mat \
                                    -e ${BOLDOUTDIR}/reg/${BOLDPREFIX}2${T1PREFIX}.mat \
                                    -f Linear
         mkdir -p ${BOLDOUTDIR}/stats/${meas}
         for ATLAS in DKAseg SchaeferAseg
         do
           if [[ $ATLAS == "DKAseg" ]]
           then
               LABEL=${PhiPipe}/atlases/DKAseg/DKAseg_labels.txt
           else
               LABEL=${PhiPipe}/atlases/SchaeferAseg/Schaefer.100Parcels.7Networks.Aseg_labels.txt
           fi
           bash ${PhiPipe}/roi_stats.sh -a ${BOLDOUTDIR}/native/${BOLDPREFIX}_${meas}.nii.gz \
                                    -b ${BOLDOUTDIR}/stats/${meas} \
                                    -c ${BOLDPREFIX}_${ATLAS}_${meas} \
                                    -d ${BOLDOUTDIR}/masks/${BOLDPREFIX}_${ATLAS}.nii.gz \
                                    -e ${LABEL}      
         done
       done
    ) >> ${BOLDLOGDIR}/${BOLDPREFIX}_output.log 2>> ${BOLDLOGDIR}/${BOLDPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "BOLD Processing:Step 9 Failed!"
        exit 1
    fi
fi
