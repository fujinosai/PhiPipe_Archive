#! /bin/bash

## DTI model fitting for diffusion weighted images
## written by Alex / 2019-09-03 / free_learner@163.com
## written by Alex / 2020-04-04 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` DTI model fitting of dwi images using FSL's dtifit

Usage example:

bash $0 -a /home/alex/data/dwi.nii.gz 
        -b /home/alex/data 
        -c dti 
        -d /home/alex/data/bvals
        -e /home/alex/data/bvecs
        -f /home/alex/data/dwi_brainmask.nii.gz

Required arguments:

        -a:  4D dwi image
        -b:  output directory
        -c:  output prefix
        -d:  b values
        -e:  b vectors
        -f:  dwi brain mask

USAGE
    exit 1
}

## parse arguments 
if [[ $# -lt 6 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## dwi file
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
          f) ## brain mask
             BRAINMASK=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## select the volumes with the lowest non-zero b value if multi-shell data is provided
Rscript -e "Args <- commandArgs(TRUE);\
            bvals <- scan(Args[1]);\
            idx <- numeric(length=length(bvals));\
            idx <- ifelse(bvals<100, TRUE, FALSE);\
            minmax <- range(bvals[!idx]);\
            diff <- abs(minmax[1] - minmax[2]);\
            if ( diff > 100){;\
                idx <- which(idx | abs(bvals - minmax[1]) < 100);\
                bvecs <- read.table(Args[2]);\
                write.table(t(idx-1), Args[3], quote=FALSE, row.names=FALSE, col.names=FALSE, sep=',');\
                write.table(t(bvals[idx]), Args[4], quote=FALSE, row.names=FALSE, col.names=FALSE);\
                write.table(bvecs[,idx], Args[5], quote=FALSE, row.names=FALSE, col.names=FALSE);\
            };\
           " ${BVAL} ${BVEC} ${OUTDIR}/volumes_list.txt ${OUTDIR}/single_shell.bval ${OUTDIR}/single_shell.bvec

## dtifit
if [[ -f ${OUTDIR}/volumes_list.txt ]]
then
    echo "multi-shell data detected, please check!!!"
    # volume index starts at 0 !!!
    # 3dcalc is more than 10 times faster than fslselectvols
    #fslselectvols -i ${DWIIMAGE} -o ${OUTDIR}/single_shell.nii.gz --vols=$(cat ${OUTDIR}/volumes_list.txt)
    volist=$(cat ${OUTDIR}/volumes_list.txt)
    3dcalc -a "${DWIIMAGE}[$volist]" -expr 'a' -prefix ${OUTDIR}/single_shell.nii.gz
    dtifit -k ${OUTDIR}/single_shell.nii.gz -o ${OUTDIR}/${PREFIX} -m ${BRAINMASK} -r ${OUTDIR}/single_shell.bvec -b ${OUTDIR}/single_shell.bval
else
    dtifit -k ${DWIIMAGE} -o ${OUTDIR}/${PREFIX} -m ${BRAINMASK} -r ${BVEC} -b ${BVAL}
fi
cd ${OUTDIR}
ln -s ${PREFIX}_L1.nii.gz ${OUTDIR}/${PREFIX}_AD.nii.gz
3dcalc -a ${OUTDIR}/${PREFIX}_L2.nii.gz -b ${OUTDIR}/${PREFIX}_L3.nii.gz -expr '(a+b)/2' -prefix ${OUTDIR}/${PREFIX}_RD.nii.gz

