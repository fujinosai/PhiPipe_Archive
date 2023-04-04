#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------------------------------------------
`basename $0` creates BOLD fMRI brain/wm/csf/parcellation masks and make snapshots for quality check
-----------------------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold.nii.gz
        -b /home/alex/output
        -c bold
        -d /home/alex/input/t1_brainmask.nii.gz
        -e /home/alex/input/t1_gmmask.nii.gz
        -f /home/alex/input/t1_wmmask.nii.gz
        -g /home/alex/input/t1_csfmask.nii.gz
        -h /home/alex/input/bold2t1.dat
        -i /home/alex/input/t1_DKAseg.nii.gz
        -j /home/alex/input/t1_SchaeferAseg.nii.gz
-----------------------------------------------------------------------------------------------------
Required arguments:
        -a: 4D BOLD fMRI images  
        -b: output directory
        -c: output prefix
        -d: T1 brain mask
        -e: T1 gray matter mask
        -f: T1 white matter mask
        -g: T1 csf mask
        -h: BOLD-T1 BBR registration matrix (FreeSurfer format)

Optional arguments:
        -i: T1 DKAseg Atlas mask
        -j: T1 SchaeferAseg Atlas mask
-----------------------------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 16 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:g:h:i:j:" OPT
    do
      case $OPT in
          a) ## bold fMRI image file
             BOLDIMAGE=$OPTARG
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
          e) ## T1 gm mask
             T1GMMASK=$OPTARG
             ;;
          f) ## T1 wm mask
             T1WMMASK=$OPTARG
             ;;
          g) ## T1 csf mask
             T1CSFMASK=$OPTARG
             ;;
          h) ## BBR registration matrix
             BBRMAT=$OPTARG
             ;;
          i) ## T1 DKAseg Atlas mask
             T1DKAseg=$OPTARG
             ;;
          j) ## T1 SchaeferAseg Atlas mask
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
bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${T1BRAINMASK} -a ${T1GMMASK} -a ${T1WMMASK} -a ${T1CSFMASK} -a ${BBRMAT} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## brain mask
## first estimate the whole brain mask using AFNI's 3dAutomask and dilate a little
## second transform T1 brain mask into fMRI space and dilate a little
## third the intersection of two whole brain masks is the final brain mask
## calculate whole brain mean signals (also called global signal), which could be used in nuisance regression
## temporarily create a reference file, which was explicitly provided in previous versions.
3dAutomask -dilate 1 -prefix ${OUTDIR}/mytmp_automask.nii.gz ${BOLDIMAGE}
3dTstat -mean -prefix ${OUTDIR}/mytmp_mean.nii.gz ${BOLDIMAGE}
REFIMAGE=${OUTDIR}/mytmp_mean.nii.gz
## get the robust intensity range of reference image for visualization
MinMax=($(fslstats ${REFIMAGE} -r))
## here I use antsApplyTransforms to convert masks from T1 space to fMRI space. Also it could be done using FreeSurfer's mri_label2vol:
## mri_label2vol --seg t1_wmmask.nii.gz --temp rest_ref.nii.gz --reg rest2t1.dat --o rest_wmmask.nii.gz
## the methods had small difference on the edges after simple testing. However, I don't know the cause and which is better
## After a second thought, I choose to use mri_label2vol and mri_vol2vol to replace antsApplyTransforms, because the BOLD-T1 registration is performed using FreeSurfer's bbregister, and FreeSurfer's mri_label2vol/mri_vol2vol seems a more natural selection to use the registration results. If ANTs is not used in the future versions, the codes would still work.
## After simple testing, the results between antsApplyTransforms and mri_vol2vol are the same, but the qform/sform in the output are slightly different, possibly because of precision errors.
mri_label2vol --seg ${T1BRAINMASK} --temp ${REFIMAGE} --reg ${BBRMAT} --o ${OUTDIR}/mytmp_brainmask.nii.gz
3dmask_tool -input ${OUTDIR}/mytmp_brainmask.nii.gz -dilate_input 1 -prefix ${OUTDIR}/mytmp_brainmask_dilt.nii.gz
3dcalc -a ${OUTDIR}/mytmp_brainmask_dilt.nii.gz -b ${OUTDIR}/mytmp_automask.nii.gz -expr 'a*b' -prefix ${OUTDIR}/${PREFIX}_brainmask.nii.gz 
3dmaskave -mask ${OUTDIR}/${PREFIX}_brainmask.nii.gz -quiet ${BOLDIMAGE} > ${OUTDIR}/${PREFIX}_brain.mean
## output the number of non-zero voxels for trouble-shooting
VoxCount=$(fslstats ${OUTDIR}/${PREFIX}_brainmask.nii.gz -V | awk '{print $1}')
printf "%s: %d\n" "Brain" $VoxCount > ${OUTDIR}/${PREFIX}_maskvol.count
## gm mask
## transform T1 GM mask into fMRI space (dilation is not a good idea after test)
## intersect the GM and brain masks to account for partial FOV in fMRI
## calculate GM mean signals, which could be used as a proxy for global mean signals in nuisance regression
mri_label2vol --seg ${T1GMMASK} --temp ${REFIMAGE} --reg ${BBRMAT} --o ${OUTDIR}/mytmp_gmmask.nii.gz
3dcalc -a ${OUTDIR}/mytmp_gmmask.nii.gz -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -expr 'a*b' -prefix ${OUTDIR}/${PREFIX}_gmmask.nii.gz
3dmaskave -mask ${OUTDIR}/${PREFIX}_gmmask.nii.gz -quiet ${BOLDIMAGE} > ${OUTDIR}/${PREFIX}_gm.mean
## output the number of non-zero voxels for trouble-shooting
VoxCount=$(fslstats ${OUTDIR}/${PREFIX}_gmmask.nii.gz -V | awk '{print $1}')
printf "%s: %d\n" "GM" $VoxCount >> ${OUTDIR}/${PREFIX}_maskvol.count
## wm mask
## transform T1 WM mask into fMRI space and erode a little to account for partial volume effect
## intersect the WM and brain masks to account for partial FOV in fMRI
## intersect the WM and non-GM masks to account for partial volume effect in fMRI (although very unlikely because of erosion, still included to track the idea)
## calculate WM mean signals, which could be used in nuisance regression
mri_label2vol --seg ${T1WMMASK} --temp ${REFIMAGE} --reg ${BBRMAT} --o ${OUTDIR}/mytmp_wmmask.nii.gz
3dmask_tool -input ${OUTDIR}/mytmp_wmmask.nii.gz -dilate_input -1 -prefix ${OUTDIR}/mytmp_wmmask_ero.nii.gz
3dcalc -a ${OUTDIR}/mytmp_wmmask_ero.nii.gz -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR}/${PREFIX}_gmmask.nii.gz -expr 'a*b*not(c)' -prefix ${OUTDIR}/${PREFIX}_wmmask.nii.gz
3dmaskave -mask ${OUTDIR}/${PREFIX}_wmmask.nii.gz -quiet ${BOLDIMAGE} > ${OUTDIR}/${PREFIX}_wm.mean
## output the number of non-zero voxels for trouble-shooting
VoxCount=$(fslstats ${OUTDIR}/${PREFIX}_wmmask.nii.gz -V | awk '{print $1}')
printf "%s: %d\n" "WM" $VoxCount >> ${OUTDIR}/${PREFIX}_maskvol.count
# csf mask
## transform T1 CSF mask into fMRI space and erode a little to account for partial volume effect
## the erosion of (inner) CSF mask is different from WM mask, as the CSF mask is small
## intersect the CSF and brain masks to account for partial FOV in fMRI
## intersect the CSF and GM masks to account for partial volume effect in fMRI
## calculate CSF mean signals, which could be used in nuisance regression
mri_vol2vol --targ ${T1CSFMASK} --mov ${REFIMAGE} --reg ${BBRMAT} --inv --o ${OUTDIR}/mytmp_csfmask.nii.gz --trilin
3dcalc -a ${OUTDIR}/mytmp_csfmask.nii.gz -expr 'ispositive(a-0.9)' -prefix ${OUTDIR}/mytmp_csfmask_ero.nii.gz
3dcalc -a ${OUTDIR}/mytmp_csfmask_ero.nii.gz -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR}/${PREFIX}_gmmask.nii.gz -expr 'a*b*not(c)' -prefix ${OUTDIR}/${PREFIX}_csfmask.nii.gz
3dmaskave -mask ${OUTDIR}/${PREFIX}_csfmask.nii.gz -quiet ${BOLDIMAGE} > ${OUTDIR}/${PREFIX}_csf.mean
## output the number of non-zero voxels for trouble-shooting
VoxCount=$(fslstats ${OUTDIR}/${PREFIX}_csfmask.nii.gz -V | awk '{print $1}')
printf "%s: %d\n" "CSF" $VoxCount >> ${OUTDIR}/${PREFIX}_maskvol.count
## check the correlation among mean signals from different tissue masks for trouble-shooting. As expected, whole brain and GM should be very similar, and WM/CSF should be independent from each other and from whole brain/GM
1dcat ${OUTDIR}/${PREFIX}_brain.mean ${OUTDIR}/${PREFIX}_gm.mean ${OUTDIR}/${PREFIX}_wm.mean ${OUTDIR}/${PREFIX}_csf.mean > ${OUTDIR}/mytmp_maskts.1D
1ddot -terse -dem ${OUTDIR}/mytmp_maskts.1D > ${OUTDIR}/mytmp_maskcc.matrix
printf "%s\n%s\n%s\n%s\n" "Brain" "GM" "WM" "CSF" > ${OUTDIR}/mytmp_row.name
paste ${OUTDIR}/mytmp_row.name ${OUTDIR}/mytmp_maskcc.matrix > ${OUTDIR}/${PREFIX}_maskcc.matrix

## visual check bold masks
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_brainmask -e 1 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_gmmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_gmmask -e 0 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_wmmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_wmmask -e 0 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${REFIMAGE} -b ${OUTDIR}/${PREFIX}_csfmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_csfmask -e 0 -f 1
## check if output files successfully created
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_brainmask.nii.gz -a ${OUTDIR}/${PREFIX}_gmmask.nii.gz -a ${OUTDIR}/${PREFIX}_wmmask.nii.gz -a ${OUTDIR}/${PREFIX}_csfmask.nii.gz
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
    ## transform DKAseg mask from T1 space into fMRI space
    ## the DKAseg mask was not intersected with whole brain mask/GM mask, because the potential signal loss could be used to indicate fMRI data quality
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
    ## transform SchaeferAseg mask from T1 space into fMRI space
    ## the SchaeferAseg mask was not intersected with whole brain mask/GM mask, because the potential signal loss could be used to indicate fMRI data quality
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

