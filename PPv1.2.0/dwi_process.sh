#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------------------
`basename $0` is the default processing pipeline for DWI images
---------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/output/t1_proc
        -b t1
        -c /home/alex/input/dwi.nii.gz
        -d /home/alex/output/dwi_proc
        -e dwi 
        -f /home/alex/input/bvals 
        -g /home/alex/input/bvecs
        -h 2
        -i 0
---------------------------------------------------------------------------
Required arguments:
        -a:  T1 output directory (created by t1_process.sh)
        -c:  DWI images
        -f:  b-value file
        -g:  b-vector file
        -h:  phase encoding direction (X/Y/Z:1/2/3)

Optional arguments:
        -b:  T1 output prefix (default: t1)
        -d:  DWI output directory (default: dwi_proc in input data folder)
        -e:  DWI output prefix (default: dwi)
        -i:  do probabilistic tractography (default: 0)
---------------------------------------------------------------------------
USAGE
    exit 1
}

if [[ $# -lt 10 ]] ; then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:g:h:i:" OPT
    do
      case $OPT in
          a) ## T1 output directory
             T1OUTDIR=$OPTARG
             ;;
          b) ## T1 output prefix
             T1PREFIX=$OPTARG
             ;;
          c) ## DWI image
             DWIIMAGE=$OPTARG
             ;;
          d) ## DWI output directory
             DWIOUTDIR=$OPTARG
             ;;
          e) ## DWI output prefix
             DWIPREFIX=$OPTARG
             ;;
          f) ## b-value
             BVAL=$OPTARG
             ;;
          g) ## b-vector
             BVEC=$OPTARG
             ;;
          h) ## phase encoding direction
             PEDIR=$OPTARG
             ;;
          i) ## do probtrack
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
if [[ -z ${PhiPipe} ]]
then
    echo "please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if INPUT files/folders exist?
bash ${PhiPipe}/check_inout.sh -a ${DWIIMAGE} -a ${BVAL} -a ${BVEC} -b ${T1OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## custom output directory
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
DWILOGDIR=${DWIOUTDIR}/log
mkdir -p ${DWILOGDIR}

## dashed line to segment code blocks for clarity in the log file
segline() {
 local INFO=$1
 echo "--------------------------${INFO}-----------------------------"
}

## save date and PhiPipe version information
date +"%Y-%m-%d %H:%M:%S" >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
segline "Software information" >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
cat ${PhiPipe}/VERSION | sed -n 2p >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log

## save dependent software information (remove lines started with "-")
bash ${PhiPipe}/check_dependencies.sh | sed '/^-/d' >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log

## Start DWI Processing
## (1) B0 to T1 BBR Registration
segline "DWI Processing:Step 1" | tee -a ${DWILOGDIR}/${DWIPREFIX}_output.log >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
if [[ ! -f ${DWIOUTDIR}/reg/${DWIPREFIX}2${T1PREFIX}.mat ]]
then
    (set -x
        mkdir -p ${DWIOUTDIR}/reg
        fslroi ${DWIIMAGE} ${DWIOUTDIR}/reg/${DWIPREFIX}_b0.nii.gz 0 1
        bash ${PhiPipe}/reg_bbr.sh -a ${DWIOUTDIR}/reg/${DWIPREFIX}_b0.nii.gz \
                                   -b ${T1OUTDIR}/freesurfer \
                                   -c ${DWIOUTDIR}/reg \
                                   -d ${DWIPREFIX}2${T1PREFIX} \
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "DWI Processing:Step 1 Failed!"
        exit 1
    fi
fi

## (2) Make DWI Masks
segline "DWI Processing:Step 2" | tee -a ${DWILOGDIR}/${DWIPREFIX}_output.log >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
if [[ ! -f ${DWIOUTDIR}/masks/${DWIPREFIX}_brainmask.nii.gz ]]
then
    (set -x
       mkdir -p ${DWIOUTDIR}/masks
       bash ${PhiPipe}/dwi_mask.sh -a ${DWIOUTDIR}/reg/${DWIPREFIX}_b0.nii.gz \
                             -b ${DWIOUTDIR}/masks \
                             -c ${DWIPREFIX} \
                             -d ${T1OUTDIR}/masks/${T1PREFIX}_brainmask.nii.gz \
                             -e ${DWIOUTDIR}/reg/${DWIPREFIX}2${T1PREFIX}.dat \
                             -f ${T1OUTDIR}/masks/${T1PREFIX}_DKAseg.nii.gz \
                             -g ${T1OUTDIR}/masks/${T1PREFIX}_SchaeferAseg.nii.gz
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "DWI Processing:Step 2 Failed!"
        exit 1
    fi
fi

## (3) Eddy & Motion Correction
segline "DWI Processing:Step 3" | tee -a ${DWILOGDIR}/${DWIPREFIX}_output.log >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
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
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "DWI Processing:Step 3 Failed!"
        exit 1
    fi
fi

## (4) Diffusion Tensor Fitting
segline "DWI Processing:Step 4" | tee -a ${DWILOGDIR}/${DWIPREFIX}_output.log >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
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
    )  >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "DWI Processing:Step 4 Failed!"
        exit 1
    fi
fi

## (5) Extract Mean DTI Metrics based on JHU Atlas
segline "DWI Processing:Step 5" | tee -a ${DWILOGDIR}/${DWIPREFIX}_output.log >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
if [[ ! -f ${DWIOUTDIR}/stats/dti/${DWIPREFIX}_JHUlabel_FA.mean ]]
then
    (set -x
       JHULABEL=${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz
       JHUTRACT=${FSLDIR}/data/atlases/JHU/JHU-ICBM-tracts-maxprob-thr25-1mm.nii.gz
       mkdir -p ${DWIOUTDIR}/stats/dti
       for MEAS in FA MD AD RD
       do
         ## JHU label Atlas
         bash ${PhiPipe}/roi_stats.sh -a ${DWIOUTDIR}/dtifit/${DWIPREFIX}_mni${MEAS}.nii.gz \
                                -b ${DWIOUTDIR}/stats/dti \
                                -c ${DWIPREFIX}_JHUlabel_${MEAS} \
                                -d ${JHULABEL} \
                                -e ${PhiPipe}/atlases/JHU/JHUlabel_labels.txt
         ## JHU tract Atlas
         bash ${PhiPipe}/roi_stats.sh -a ${DWIOUTDIR}/dtifit/${DWIPREFIX}_mni${MEAS}.nii.gz \
                                -b ${DWIOUTDIR}/stats/dti \
                                -c ${DWIPREFIX}_JHUtract_${MEAS} \
                                -d ${JHUTRACT} \
                                -e ${PhiPipe}/atlases/JHU/JHUtract_labels.txt        
       done
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "DWI Processing:Step 5 Failed!"
        exit 1
    fi
fi

## By default, the probabilistic tractography was disabled as it is very time-consuming
if [[ -z ${DOPT} ]]
then
    DOPT=0
fi

if [[ ${DOPT} -eq 1 ]]
then
## (6) Fiber Orientation Distribution Estimation
segline "DWI Processing:Step 6" | tee -a ${DWILOGDIR}/${DWIPREFIX}_output.log >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
if [[ ! -f ${DWIOUTDIR}/bedpostx/merged_f1samples.nii.gz ]]
then
    (set -x
     ## if multi-shell data, use model=2, else use model=1
     if [[ -f ${DWIOUTDIR}/dtifit/single_shell.nii.gz ]]
     then
         bash ${PhiPipe}/dwi_bedpostx.sh -a ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.nii.gz \
                             -b ${DWIOUTDIR} \
                             -c bedpostx \
                             -d ${DWIOUTDIR}/masks/${DWIPREFIX}_brainmask.nii.gz \
                             -e ${BVAL} \
                             -f ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.eddy_rotated_bvecs \
                             -g 2
     else
         bash ${PhiPipe}/dwi_bedpostx.sh -a ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.nii.gz \
                             -b ${DWIOUTDIR} \
                             -c bedpostx \
                             -d ${DWIOUTDIR}/masks/${DWIPREFIX}_brainmask.nii.gz \
                             -e ${BVAL} \
                             -f ${DWIOUTDIR}/eddy/${DWIPREFIX}_correct.eddy_rotated_bvecs \
                             -g 1      
     fi
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "DWI Processing:Step 6 Failed!"
        exit 1
    fi
fi

## (7) probability tractography
segline "DWI Processing:Step 7" | tee -a ${DWILOGDIR}/${DWIPREFIX}_output.log >> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
if [[ ! -f ${DWIOUTDIR}/probtrackx/DKAseg/DKAseg_prob.matrix ]]
then
    (set -x
     ## loop through parcellation masks
     for ATLAS in DKAseg SchaeferAseg
     do
       if [[ $ATLAS == "DKAseg" ]]
       then
           LABEL=${PhiPipe}/atlases/DKAseg/DKAseg_labels.txt
       else
           LABEL=${PhiPipe}/atlases/SchaeferAseg/Schaefer.100Parcels.7Networks.Aseg_labels.txt
       fi
       mkdir -p ${DWIOUTDIR}/probtrackx/${ATLAS}
       bash ${PhiPipe}/dwi_probtrackx.sh -a ${DWIOUTDIR}/bedpostx \
                             -b ${DWIOUTDIR}/probtrackx/${ATLAS} \
                             -c ${ATLAS}_prob \
                             -d ${DWIOUTDIR}/masks/${DWIPREFIX}_${ATLAS}.nii.gz \
                             -e ${LABEL}
       ## copy structural connectivity matrix into stats folder
       mkdir -p ${DWIOUTDIR}/stats/probtrackx
       cp ${DWIOUTDIR}/probtrackx/${ATLAS}/${ATLAS}_prob.matrix ${DWIOUTDIR}/stats/probtrackx/${DWIPREFIX}_${ATLAS}_prob.matrix
       cp ${DWIOUTDIR}/probtrackx/${ATLAS}/${ATLAS}_prob.info ${DWIOUTDIR}/stats/probtrackx/${DWIPREFIX}_${ATLAS}_prob.info
     done
    ) >> ${DWILOGDIR}/${DWIPREFIX}_output.log 2>> ${DWILOGDIR}/${DWIPREFIX}_cmd.log
    ## check the final status
    if [[ $? -eq 1 ]]
    then
        echo "DWI Processing:Step 6 Failed!"
        exit 1
    fi
fi
fi
