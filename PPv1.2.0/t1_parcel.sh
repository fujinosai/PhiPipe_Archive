#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
------------------------------------------------------------------------------------------
`basename $0` parcellates the brain using non-builtin atlases based on recon-all results
------------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/freesurfer
        -b 1
------------------------------------------------------------------------------------------
Required arguments:
        -a: FreeSurfer recon-all directory
        -b: use Schaefer Atlas to parcellate the brain (set 1 to turn on)
------------------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 4 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:" OPT
    do
      case $OPT in
          a) ## recon-all directory
             RECONALL=$OPTARG
             ;;
          b) ## use Schaefer Atlas
             USESchaefer=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -b ${RECONALL}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## set FreeSurfer required environmental variables
export SUBJECTS_DIR=$(dirname ${RECONALL})
SUBJECT=$(basename ${RECONALL})

## use Schaefer Atlas
## these codes were modified based on the Yeolab's Github page: https://github.com/ThomasYeoLab/CBIG/tree/master/stable_projects/brain_parcellation/Schaefer2018_LocalGlobal/Parcellations/project_to_individual
if [[ ${USESchaefer} -eq 1 ]]
then
    ## project Schaefer cortical parcellation into individual surface space
    for hemi in lh rh
    do    
      mris_ca_label -l ${SUBJECTS_DIR}/${SUBJECT}/label/${hemi}.cortex.label ${SUBJECT} ${hemi} ${SUBJECTS_DIR}/${SUBJECT}/surf/${hemi}.sphere.reg ${PhiPipe}/atlases/SchaeferAseg/${hemi}.Schaefer2018_100Parcels_7Networks.gcs ${SUBJECTS_DIR}/${SUBJECT}/label/${hemi}.Schaefer.100Parcels.7Networks.annot
      mris_anatomical_stats -mgz -cortex ${SUBJECTS_DIR}/${SUBJECT}/label/${hemi}.cortex.label -f ${SUBJECTS_DIR}/${SUBJECT}/stats/${hemi}.Schaefer.100Parcels.7Networks.stats -b -a ${SUBJECTS_DIR}/${SUBJECT}/label/${hemi}.Schaefer.100Parcels.7Networks.annot ${SUBJECT} ${hemi} white
    done
    ## project parcellation into individual volume space
    mri_aparc2aseg --s ${SUBJECT} --o ${SUBJECTS_DIR}/${SUBJECT}/mri/Schaefer.100Parcels.7Networks+aseg.mgz --volmask --annot Schaefer.100Parcels.7Networks
    bash ${PhiPipe}/check_inout.sh -a ${SUBJECTS_DIR}/${SUBJECT}/label/lh.Schaefer.100Parcels.7Networks.annot -a ${SUBJECTS_DIR}/${SUBJECT}/label/rh.Schaefer.100Parcels.7Networks.annot -a ${SUBJECTS_DIR}/${SUBJECT}/stats/lh.Schaefer.100Parcels.7Networks.stats -a ${SUBJECTS_DIR}/${SUBJECT}/stats/rh.Schaefer.100Parcels.7Networks.stats
    if [[ $? -eq 1 ]]
    then
        exit 1
    fi
fi
