#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## make label files for JHU atlases
# JHU Label Atlas -- need some manual edits
index=$(seq 1 48)
labels=$(cat ${FSLDIR}/data/atlases/JHU-labels.xml | sed -n 17,64p | cut -d '>' -f2 | cut -d '<' -f1 | sed 's/\ /_/g' | sed 's/[()]//g')
paste <(echo "$index") <(echo "$labels") --delimiters ' '  > JHUlabel_labels.txt 

# JHU Tract Atlas
index=$(seq 1 20)
labels=$(cat ${FSLDIR}/data/atlases/JHU-tracts.xml | sed -n 16,35p | cut -d '>' -f2 | cut -d '<' -f1 | sed 's/\ /_/g' | sed 's/[()]//g')
paste <(echo "$index") <(echo "$labels") --delimiters ' '  > JHUtract_labels.txt

