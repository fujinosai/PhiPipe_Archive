#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
----------------------------------------------------------------------------------------
`basename $0` creates brain/gm/wm/csf/parcellation masks from FreeSurfer recon-all results,
which could be used for quality check and fMRI/DWI processing
----------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/freesurfer 
        -b /home/alex/output/masks
        -c t1
----------------------------------------------------------------------------------------
Required arguments:
        -a:  FreeSurfer recon-all directory
        -b:  output directory
        -c:  output prefix 

Optional arguments:
        -d: use DKAseg Atlas (set 1 to turn on)
        -e: use SchaeferAseg Atlas (set 1 to turn on)
----------------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## recon-all directory
             RECONALL=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## use DK Atlas
             USEDKAseg=$OPTARG
             ;;
          e) ## use Schaefer Atlas
             USESchaeferAseg=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -b ${RECONALL} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## nu.mgz is the output after the N3 bias correction
## brain binary mask: a refined version of the brain extraction in the recon-all -autorecon1
## the brain/brainmask could be used for registration/masking in fMRI/DWI processing
mri_convert ${RECONALL}/mri/nu.mgz ${OUTDIR}/${PREFIX}_biascorrect.nii.gz
mri_binarize --i ${RECONALL}/mri/aseg.mgz --min 1 --o ${OUTDIR}/${PREFIX}_brainmask.nii.gz --dilate 1
mri_mask ${RECONALL}/mri/nu.mgz ${OUTDIR}/${PREFIX}_brainmask.nii.gz ${OUTDIR}/${PREFIX}_brain.nii.gz

## white matter & ventricle binary masks
## the wmmask/csfmask could be used for masking (nuisance regression) in fMRI processing
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_wmmask.nii.gz --all-wm
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_csfmask.nii.gz --ventricles

## whole brain gray matter binary mask
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_gmmask.nii.gz --gm
## subcortical structure binary masks
mri_binarize --i ${RECONALL}/mri/aseg.mgz --o ${OUTDIR}/${PREFIX}_asegmask.nii.gz --subcort-gm
## the whole brain gray matter mask/subcortical mask are used to make DK+Aseg mask in the next step

## plot the edge of mask on bias-corrected T1 image
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_brainmask -e 2 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_gmmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_gmmask -e 2 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_wmmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_wmmask -e 2 -f 1
bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -b ${OUTDIR}/${PREFIX}_csfmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_csfmask -e 2 -f 1

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -a ${OUTDIR}/${PREFIX}_brainmask.nii.gz -a ${OUTDIR}/${PREFIX}_gmmask.nii.gz -a ${OUTDIR}/${PREFIX}_wmmask.nii.gz -a ${OUTDIR}/${PREFIX}_csfmask.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi

## get the robust intensity range of bias-corrected image for parcellation visualization
MinMax=($(fslstats ${OUTDIR}/${PREFIX}_biascorrect.nii.gz -r))

## DK+Aseg parcellation masks
if [[ ${USEDKAseg} -eq 1 ]]
then
    mri_convert ${RECONALL}/mri/aparc+aseg.mgz ${OUTDIR}/aparc+aseg.nii.gz
    ## the expression "a*step(mod(a*step(a*b-999),1000))" is to remove ctx-lh-unknown (1000)/ctx-rh-unknown (2000), and non-gray-matter regions
    ## the *DKAseg.nii.gz file contains the 68 cortical regions from DK Atlas and 19 subcortical regions from Aseg Atlas 
    3dcalc -a ${OUTDIR}/aparc+aseg.nii.gz -b ${OUTDIR}/${PREFIX}_gmmask.nii.gz -c ${OUTDIR}/${PREFIX}_asegmask.nii.gz -expr 'a*step(mod(a*step(a*b-999),1000))+a*c' -prefix ${OUTDIR}/mytmp_DKAseg.nii.gz
    ## remove Cerebellum-Cortex (8/47), Brain-Stem (16), VentralDC (28/60) from DKAseg.nii.gz as these regions are not frequently used and will increase processing time in fMRI/DWI processing 
    3dcalc -a ${OUTDIR}/mytmp_DKAseg.nii.gz -expr 'a*not(amongst(a,8,16,28,47,60))' -prefix ${OUTDIR}/${PREFIX}_DKAseg.nii.gz
    rm ${OUTDIR}/mytmp_DKAseg.nii.gz
    ## plot the parcellation mask 
    bash ${PhiPipe}/plot_freeview.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz:grayscale=${MinMax[0]},${MinMax[1]} -a ${OUTDIR}/${PREFIX}_DKAseg.nii.gz:colormap=lut:lut=${PhiPipe}/atlases/DKAseg/DKAseg_LUT.txt -d ${OUTDIR} -e ${PREFIX}_DKAseg
    ## plot the DK in 3D view
    bash ${PhiPipe}/plot_freeview.sh -b ${RECONALL}/surf/lh.pial:annot=${RECONALL}/label/lh.aparc.annot:edgethickness=0 -c ${RECONALL}/surf/rh.pial:annot=${RECONALL}/label/rh.aparc.annot:edgethickness=0 -d ${OUTDIR} -e ${PREFIX}_DK.3D
    ## check whether the output files exist
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_DKAseg.nii.gz
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi

## Schaefer+Aseg parcellation masks
if [[ ${USESchaeferAseg} -eq 1 ]]
then
    mri_convert ${RECONALL}/mri/Schaefer.100Parcels.7Networks+aseg.mgz ${OUTDIR}/Schaefer.100Parcels.7Networks+aseg.nii.gz
    3dcalc -a ${OUTDIR}/Schaefer.100Parcels.7Networks+aseg.nii.gz -b ${OUTDIR}/${PREFIX}_gmmask.nii.gz -c ${OUTDIR}/${PREFIX}_asegmask.nii.gz -expr 'a*step(mod(a*step(a*b-999),1000))+a*c' -prefix ${OUTDIR}/mytmp_Schaefer.100Parcels.7Networks.Aseg.nii.gz 
    3dcalc -a ${OUTDIR}/mytmp_Schaefer.100Parcels.7Networks.Aseg.nii.gz -expr 'a*not(amongst(a,8,16,28,47,60))' -prefix ${OUTDIR}/${PREFIX}_SchaeferAseg.nii.gz
    rm ${OUTDIR}/mytmp_Schaefer.100Parcels.7Networks.Aseg.nii.gz ${OUTDIR}/Schaefer.100Parcels.7Networks+aseg.nii.gz
    ## plot the parcellation mask
    bash ${PhiPipe}/plot_freeview.sh -a ${OUTDIR}/${PREFIX}_biascorrect.nii.gz:grayscale=${MinMax[0]},${MinMax[1]} -a ${OUTDIR}/${PREFIX}_SchaeferAseg.nii.gz:colormap=lut:lut=${PhiPipe}/atlases/SchaeferAseg/Schaefer2018_100Parcels_7Networks_LUT.txt -d ${OUTDIR} -e ${PREFIX}_SchaeferAseg
    ## plot the Schaefer in 3D view
    bash ${PhiPipe}/plot_freeview.sh -b ${RECONALL}/surf/lh.pial:annot=${RECONALL}/label/lh.Schaefer.100Parcels.7Networks.annot:edgethickness=0 -c ${RECONALL}/surf/rh.pial:annot=${RECONALL}/label/rh.Schaefer.100Parcels.7Networks.annot:edgethickness=0 -d ${OUTDIR} -e ${PREFIX}_Schaefer.100Parcels.7Networks.3D
    ## check whether the output files exist
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_SchaeferAseg.nii.gz
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi

## remove temporary files
rm ${OUTDIR}/aparc+aseg.nii.gz ${OUTDIR}/${PREFIX}_asegmask.nii.gz 
