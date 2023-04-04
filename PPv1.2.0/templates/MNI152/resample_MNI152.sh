#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## resample MNI152 T1 template into 3*3*3 mm^3
ResampleImage 3 ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz MNI152_T1_3mm_brain.nii.gz 3x3x3 0 0
