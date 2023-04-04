#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
--------------------------------------------------
`basename $0` performs diffusion tensor (DT) model fitting of DWI images
--------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/dwi.nii.gz 
        -b /home/alex/output
        -c dti 
        -d /home/alex/input/bvals
        -e /home/alex/input/bvecs
        -f /home/alex/input/dwi_brainmask.nii.gz
--------------------------------------------------
Required arguments:
        -a:  4D DWI image
        -b:  output directory
        -c:  output prefix
        -d:  b values
        -e:  b vectors
        -f:  DWI brain mask

Optional arguments:
        -g:  transform DT metrics into MNI152 space (default:1)
--------------------------------------------------
USAGE
    exit 1
}

## parse arguments 
if [[ $# -lt 12 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:g:" OPT
    do
      case $OPT in
          a) ## DWI file
             DWIIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## b values
             BVAL=$OPTARG
             ;;
          e) ## b vectors
             BVEC=$OPTARG
             ;;
          f) ## DWI brain mask
             DWIBRAINMASK=$OPTARG
             ;;
          g) ## registration using FA map
             DOFAREG=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -a ${DWIIMAGE} -a ${DWIBRAINMASK} -a ${BVAL} -a ${BVEC} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## do FA-MNI152 registration?
if [[ -z ${DOFAREG} ]]
then
    DOFAREG=1
fi

## select the volumes with the lowest non-zero b value if multi-shell data is provided
## https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind1902&L=FSL&D=0&P=117843
## In UK Biobank pipeline, also b=1000 volumes were selected for diffusion tensor fitting, see Alfaro-Almagro et al., 2018
Rscript ${PhiPipe}/R/select_dwivol.R ${BVAL} ${BVEC} ${OUTDIR}/volumes_list.txt ${OUTDIR}/single_shell.bval ${OUTDIR}/single_shell.bvec

## fit DTI model
if [[ -f ${OUTDIR}/volumes_list.txt ]]
then
    echo "multi-shell data detected, please check!!!"
    # volume index starts at 0 !!!
    # 3dcalc is more than 10 times faster than fslselectvols
    #fslselectvols -i ${DWIIMAGE} -o ${OUTDIR}/single_shell.nii.gz --vols=$(cat ${OUTDIR}/volumes_list.txt)
    volist=$(cat ${OUTDIR}/volumes_list.txt)
    3dcalc -a "${DWIIMAGE}[$volist]" -expr 'a' -prefix ${OUTDIR}/single_shell.nii.gz
    dtifit -k ${OUTDIR}/single_shell.nii.gz -o ${OUTDIR}/${PREFIX} -m ${DWIBRAINMASK} -r ${OUTDIR}/single_shell.bvec -b ${OUTDIR}/single_shell.bval
else
    dtifit -k ${DWIIMAGE} -o ${OUTDIR}/${PREFIX} -m ${DWIBRAINMASK} -r ${BVEC} -b ${BVAL}
fi

## create AD/RD measures
cd ${OUTDIR}
ln -s ${PREFIX}_L1.nii.gz ${OUTDIR}/${PREFIX}_AD.nii.gz
3dcalc -a ${OUTDIR}/${PREFIX}_L2.nii.gz -b ${OUTDIR}/${PREFIX}_L3.nii.gz -expr '(a+b)/2' -prefix ${OUTDIR}/${PREFIX}_RD.nii.gz

## register FA into FMRIB58_FA template and transform FA/MD/AD/RD into MNI152 space
## these codes were based on FSL's TBSS scripts
if [[ ${DOFAREG} -eq 1 ]]
then
    MNIFA1mm=${FSLDIR}/data/standard/FMRIB58_FA_1mm.nii.gz
    FA=${OUTDIR}/${PREFIX}_FA.nii.gz
    # erode and create mask
    X=$(fslval ${FA} dim1)
    X=$(( $X - 2 ))
    Y=$(fslval ${FA} dim2)
    Y=$(( $Y - 2))
    Z=$(fslval ${FA} dim3)
    Z=$(( $Z - 2))
    fslmaths ${FA} -min 1 -ero -roi 1 $X 1 $Y 1 $Z 0 1 ${OUTDIR}/mytmp_FA_ero.nii.gz
    fslmaths ${OUTDIR}/mytmp_FA_ero.nii.gz -bin ${OUTDIR}/mytmp_FA_mask.nii.gz
    fslmaths ${OUTDIR}/mytmp_FA_mask.nii.gz -dilD -dilD -sub 1 -abs -add ${OUTDIR}/mytmp_FA_mask.nii.gz ${OUTDIR}/mytmp_FA_mask.nii.gz -odt char
    # registration
    flirt -ref ${MNIFA1mm} -in ${OUTDIR}/mytmp_FA_ero.nii.gz -inweight ${OUTDIR}/mytmp_FA_mask.nii.gz -omat ${OUTDIR}/${PREFIX}_fa2mni.mat
    fnirt --in=${OUTDIR}/mytmp_FA_ero.nii.gz --aff=${OUTDIR}/${PREFIX}_fa2mni.mat --cout=${OUTDIR}/${PREFIX}_fa2mni_warp --config=FA_2_FMRIB58_1mm --ref=${MNIFA1mm}
    # remove temporary files
    rm ${OUTDIR}/mytmp*
    # transformation into standard space
    for MEAS in FA MD AD RD
    do
      applywarp -i ${OUTDIR}/${PREFIX}_${MEAS}.nii.gz -o ${OUTDIR}/${PREFIX}_mni${MEAS}.nii.gz -r ${MNIFA1mm} -w ${OUTDIR}/${PREFIX}_fa2mni_warp
    done
    bash ${PhiPipe}/plot_overlay.sh -a ${OUTDIR}/${PREFIX}_mniFA.nii.gz -b ${MNIFA1mm} -c ${OUTDIR} -d ${PREFIX}_fa2mni -e 1 -f 1
fi

## check whether the output files exist
if [[ ${DOFAREG} -eq 1 ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_FA.nii.gz -a ${OUTDIR}/${PREFIX}_MD.nii.gz -a ${OUTDIR}/${PREFIX}_AD.nii.gz -a ${OUTDIR}/${PREFIX}_RD.nii.gz -a ${OUTDIR}/${PREFIX}_mniFA.nii.gz -a ${OUTDIR}/${PREFIX}_mniMD.nii.gz -a ${OUTDIR}/${PREFIX}_mniAD.nii.gz -a ${OUTDIR}/${PREFIX}_mniRD.nii.gz
else
    bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_FA.nii.gz -a ${OUTDIR}/${PREFIX}_MD.nii.gz -a ${OUTDIR}/${PREFIX}_AD.nii.gz -a ${OUTDIR}/${PREFIX}_RD.nii.gz
fi

if [[ $? -eq 1 ]]
then
    exit 1
fi
