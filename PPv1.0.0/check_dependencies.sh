#! /bin/bash

## Author: Alex / free_learner@163.com / learning-archive.org

## check whether required softwares installed and their versions
 
segline() {
echo "------------------------------------------------------"
}

segline
## FreeSurfer
if [[ ! -z ${FREESURFER_HOME} ]]
then
    Version=$(cat ${FREESURFER_HOME}/VERSION)
    if [[ ! -z $Version ]]
    then
        echo $Version
    else
        echo "Unable to determine Freesurfer version!"   
    fi
else
    echo "Please install or configure Freesurfer!"
fi
segline
## FSL
if [[ ! -z ${FSLDIR} ]]
then
    Version=$(cat ${FSLDIR}/etc/fslversion)
    if [[ ! -z $Version ]]
    then    
        echo "FSL-$Version"
    else
        echo "Unable to determine FSL version!"
    fi
else
    echo "Please install or configure FSL!"
fi
segline
## AFNI
if [[ $(which afni | wc -l) -eq 1 ]]
then
    Version=$(afni -version)
    if [[ ! -z $Version ]]
    then
        echo $Version
    else
        echo "Unable to determine AFNI version!"
    fi
else
    echo "Please install or configure AFNI!" 
fi
segline
## ANTs
if [[ ! -z ${ANTSPATH} ]]
then
    ANTSDIR=$(dirname ${ANTSPATH})
    Version=$(cat ${ANTSDIR}/ANTS-build/ANTsVersionConfig.h | tail -n 1 | cut -d ' ' -f2-)
    if [[ ! -z $Version ]]
    then
        echo $Version
    else
        echo "Unable to determine AFNI version!"
    fi
else
    echo "Please install or configure ANTs!"
fi
segline
## C3D
if [[ $(which c3d | wc -l) -eq 1 ]]
then
    Version=$(c3d -version)
    if [[ ! -z $Version ]]
    then
        echo "Convert3D-$Version"
    else
        echo "Unable to determine Convert3D version!"
    fi
else
    echo "Please install or configure Convert3D!" 
fi
segline
## R
if [[ $(which Rscript | wc -l) -eq 1 ]]
then
    Version=$(Rscript -e 'R.version$version.string' | cut -d ' ' -f2- | sed 's/"//g')
    if [[ ! -z $Version ]]
    then
        echo "$Version"
    else
        echo "Unable to determine R version!"
    fi
    Version=$(Rscript -e 'if("oro.nifti" %in% rownames(installed.packages())){packageVersion("oro.nifti")}else{print("Please install oro.nifti package!")}' | sed 's/\[1\]//')
    echo "oro.nifti:$Version"
else
    echo "Please install or configure R!"
fi
segline