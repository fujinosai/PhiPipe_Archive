#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## this is an example script to process T1/REST/DWI images for one subject using PhiPipe
## you should change the paths and parameters based on your data

## ----------------------------------------------------------------
## export the path of PhiPipe to make it globally accessible
export PhiPipe=/home/alex/code/PhiPipe_v1.2.0

## ----------------------------------------------------------------
## the absolute paths for each MRI modality
## T1-weighted 
T1IMAGE=/home/alex/data/t1.nii.gz
## Resting-state fMRI
RESTIMAGE=/home/alex/data/rest.nii.gz
## Diffusion-weighted
DWIIMAGE=/home/alex/data/dwi.nii.gz
BVAL=/home/alex/data/bvals
BVEC=/home/alex/data/bvecs

## ----------------------------------------------------------------
## parameters for resting-state fMRI
## dummy scans to be removed to allow for longitudinal equilibrium
DVOL=5
## repetition time
TR=2
## slice acquisition timing (this info could be obtained in the BIDS JSON file if you use dcm2niix for dicom-nifti conversion)
## if you don't know the slice timing, just set STTYPE=0 and comment the "STFILE" line
STTYPE=7
STFILE=/home/alex/data/rest_slicetime.txt
## passband for temporal filtering, if you only want high-pass filtering, comment the "LP=0.1" 
HP=0.01
LP=0.1

## ----------------------------------------------------------------
## parameters for DWI 
## phase encoding direction (the direction in which the distortion occurs)
## "2" means Y axis and anterior-posterior direction
PEDIR=2
## do probabilistic tractography (this step is very very time consuming, you can set 0 to turn off)
DOPT=1

## ----------------------------------------------------------------
## output folder/prefix to save results
T1OUTDIR=/home/alex/results/t1_proc
T1PREFIX=t1 
RESTOUTDIR=/home/alex/results/rest_proc
RESTPREFIX=rest
DWIOUTDIR=/home/alex/results/dwi_proc
DWIPREFIX=dwi

## ----------------------------------------------------------------
## process T1 image
bash ${PhiPipe}/t1_process.sh -a ${T1IMAGE} -b ${T1OUTDIR} -c ${T1PREFIX} 
## process fMRI image
## if you had no slice timing file, remove the "-j ${STFILE}" option
## if you want high-pass filtering only, remove the "-l ${LP}" option
bash ${PhiPipe}/bold_process.sh -a ${T1OUTDIR} -b ${T1PREFIX} -c ${RESTIMAGE} -d ${RESTOUTDIR} -e ${RESTPREFIX} -f ${DVOL} -h ${TR} -i ${STTYPE} -j ${STFILE} -k ${HP} -l ${LP}
## process DWI image
bash ${PhiPipe}/dwi_process.sh -a ${T1OUTDIR} -b ${T1PREFIX} -c ${DWIIMAGE} -d ${DWIOUTDIR} -e ${DWIPREFIX} -f ${BVAL} -g ${BVEC} -h ${PEDIR} -i ${DOPT}
## the end
