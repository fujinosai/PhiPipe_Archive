#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
------------------------------------------------------------------------------------------
`basename $0` creates DWI brain/parcellation masks and makes snapshots for quality check
------------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/dwi_b0.nii.gz
        -b /home/alex/output
        -c dwi
        -d /home/alex/input/t1_brainmask.nii.gz
        -e /home/alex/input/dwi2t1.dat
        -f /home/alex/input/t1_DKAseg.nii.gz
------------------------------------------------------------------------------------------
Required arguments:
        -a: DWI b0 image
        -b: output directory
        -c: output prefix
        -d: T1 brain mask
        -e: DWI-T1 BBR registration matrix (FreeSurfer format)

Optional arguments:
        -f: T1 DKAseg Atlas mask
        -g: T1 SchaeferAseg Atlas mask
------------------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 10 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:g:" OPT
    do
      case $OPT in
          a) ## DWI b0 image file
             B0IMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## T1 brain mask
             T1BRAINMASK=$OPTARG
             ;;
          e) ## BBR registration matrix
             BBRMAT=$OPTARG
             ;;
          f) ## t1 DKAseg Atlas mask
             T1DKAseg=$OPTARG
             ;;
          g) ## t1 SchaeferAseg Atlas mask
             T1SchaeferAseg=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## if PhiPipe variable is set?
if [[ -z ${PhiPipe} ]]
then
    echo "Please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if INPUT file/OUTPUT folder exist?
bash ${PhiPipe}/check_inout.sh -a ${B0IMAGE} -a ${T1BRAINMASK} -a ${BBRMAT} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi
          
## brain mask
## first estimate the whole brain mask using FSL's bet2
## second transform T1 brain mask into DWI space and dilate a little
## third the intersection of two whole brain masks is the final brain mask
REFIMAGE=${B0IMAGE}
## get the robust intensity range of reference image for visualization
MinMax=($(fslstats ${REFIMAGE} -r))
## -f 0.2 to avoid removing brain tissues
bet2 ${B0IMAGE} ${OUTDIR}/mytmp_bet -f 0.2 -m
mri_label2vol --seg ${T1BRAINMASK} --temp ${REFIMAGE} --reg ${BBRMAT} --o ${OUTDIR}/mytmp_brainmask.nii.gz
3dmask_tool -input ${OUTDIR}/mytmp_brainmask.nii.gz -dilate_input 1 -prefix ${OUTDIR}/mytmp_brainmask_dilt.nii.gz
3dcalc -a ${OUTDIR}/mytmp_brainmask_dilt.nii.gz -b ${OUTDIR}/mytmp_bet_mask.nii.gz -expr 'a*b' -prefix ${OUTDIR}/${PREFIX}_brainmask.nii.gz
## check dwi masks
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_brainmask -e 1 -f 1
## check if output files successfully created
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_brainmask.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi

## DKAseg mask
if [[ ! -z ${T1DKAseg} ]]
then
    ## check whether the input files exist
    bash ${PhiPipe}/check_inout.sh -a ${T1DKAseg}
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
    ## transform DKAseg mask from T1 space into DWI space
    ## the DKAseg mask was not intersected with whole brain mask, because the potential signal loss could be used to indicate DWI data quality
    mri_label2vol --seg ${T1DKAseg} --temp ${REFIMAGE} --reg ${BBRMAT} --o ${OUTDIR}/${PREFIX}_DKAseg.nii.gz
    ## plot the parcellation mask
    bash ${PhiPipe}/plot_freeview.sh -a ${REFIMAGE}:grayscale=${MinMax[0]},${MinMax[1]} -a ${OUTDIR}/${PREFIX}_DKAseg.nii.gz:colormap=lut:lut=${PhiPipe}/atlases/DKAseg/DKAseg_LUT.txt -d ${OUTDIR} -e ${PREFIX}_DKAseg
    ## check whether the output files exist
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_DKAseg.nii.gz
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi

## SchaeferAseg mask
if [[ ! -z ${T1SchaeferAseg} ]]
then
    ## check whether the input files exist
    bash ${PhiPipe}/check_inout.sh -a ${T1SchaeferAseg}
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
    ## transform SchaeferAseg mask from T1 space into DWI space
    ## the SchaeferAseg mask was not intersected with whole brain mask, because the potential signal loss could be used to indicate DWI data quality
    mri_label2vol --seg ${T1SchaeferAseg} --temp ${REFIMAGE} --reg ${BBRMAT} --o ${OUTDIR}/${PREFIX}_SchaeferAseg.nii.gz
    ## plot the parcellation mask 
    bash ${PhiPipe}/plot_freeview.sh -a ${REFIMAGE}:grayscale=${MinMax[0]},${MinMax[1]} -a ${OUTDIR}/${PREFIX}_SchaeferAseg.nii.gz:colormap=lut:lut=${PhiPipe}/atlases/SchaeferAseg/Schaefer2018_100Parcels_7Networks_LUT.txt -d ${OUTDIR} -e ${PREFIX}_SchaeferAseg
    ## check whether the output files exist
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_SchaeferAseg.nii.gz
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi

## remove temporary files
rm ${OUTDIR}/mytmp*

