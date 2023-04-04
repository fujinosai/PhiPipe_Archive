#! /bin/bash

## slice timing correction of bold fMRI images using AFNI
## written by Alex / 2019-01-09 / free_learner@163.com 
## revised by Alex / 2019-06-26 / free_learner@163.com
## revised by Alex / 2019-09-13 / free_learner@163.com
## revised by Alex / 2020-04-02 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` performs slice timing correction of bold fMRI images

Usage example:

bash $0 -a /home/alex/data/rest.nii.gz 
        -b /home/alex/data
        -c rest_st
        -d 2 
        -e 4

Required arguments:

        -a:  4D bold fMRI image
        -b:  output directory
        -c:  output prefix
        -d:  repetition time
        -e:  slice timing type

Slice timing type:

        0: skip slice timing for multi-band acquisition
        1: seqplus (1 2 3 ...)
        2: seqminus (... 3 2 1)
        3: altplus (1 3 5 ... 2 4 6 ...)
        4: altplus2 (2 4 6 ... 1 3 5 ...)
        5: altminus (n n-2 n-4 ... n-1 n-3 n-5 ...)
        6: altminus2 (n-1 n-3 n-5 ... n n-2 n-4)

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 5 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## bold fMRI file
             BOLDIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## repetition time
             TR=$OPTARG
             ;;
          e) ## slice time type
             STTYPE=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## slice timing correction
  case ${STTYPE} in
     0) cp ${BOLDIMAGE} ${OUTDIR}/${PREFIX}.nii.gz;;
     1) 3dTshift -TR ${TR} -tpattern seq+z  -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     2) 3dTshift -TR ${TR} -tpattern seq-z  -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     3) 3dTshift -TR ${TR} -tpattern alt+z  -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     4) 3dTshift -TR ${TR} -tpattern alt+z2 -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     5) 3dTshift -TR ${TR} -tpattern alt-z  -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     6) 3dTshift -TR ${TR} -tpattern alt-z2 -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     *) echo "incorrect slice timing option";;
  esac

