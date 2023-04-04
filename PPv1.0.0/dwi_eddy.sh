#! /bin/bash

## eddy correction & motion correction for diffusion weighted images
## written by Alex / 2019-09-03 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` performs eddy & motion correction of dwi images using FSL's eddy_openmp

Usage example:

bash $0 -a /home/alex/data/dwi.nii.gz 
        -b /home/alex/data 
        -c eddy_correct 
        -d /home/alex/data/bvals
        -e /home/alex/data/bvecs
        -f /home/alex/data/dwi_brainmask.nii.gz
        -g 2
        -h 1

Required arguments:

        -a:  4D dwi image
        -b:  output directory
        -c:  output prefix
        -d:  b values
        -e:  b vectors
        -f:  dwi brain mask
        -g:  phase encoding direction (1/2/3:X/Y/Z)

Optional arguments:

        -h:  enable outlier replacement (default:1)

USAGE
    exit 1
}

## parse arguments 
if [[ $# -lt 7 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:" OPT
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
          g) ## phase encoding direction
             PEDIR=$OPTARG
             ;; 
          h) ## outlier replacement
             REPOL=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## enable outlier replacement by default
if [[ -z ${REPOL} ]]
then
   REPOL=1
fi

## create acqparams.txt & index.txt files
case ${PEDIR} in
   1) echo 1 0 0 0.05 > ${OUTDIR}/acqparams.txt;;
   2) echo 0 1 0 0.05 > ${OUTDIR}/acqparams.txt;;
   3) echo 0 0 1 0.05 > ${OUTDIR}/acqparams.txt;;
   *) echo "incorrect phase encoding direction option";;
esac
NVOL=$(3dinfo -nv ${DWIIMAGE})
idx=""
for ((i=1;i<=${NVOL};i+=1))
do
    idx="${idx} 1";
done
echo $idx > ${OUTDIR}/index.txt

## eddy & motion correction
if [[ ${REPOL} -eq 1 ]]
then
  eddy_openmp --imain=${DWIIMAGE} --mask=${BRAINMASK} --acqp=${OUTDIR}/acqparams.txt --index=${OUTDIR}/index.txt --bvecs=${BVEC} --bvals=${BVAL} --out=${OUTDIR}/${PREFIX} --repol --niter=8 --fwhm=10,6,4,2,0,0,0,0 -v
else
  eddy_openmp --imain=${DWIIMAGE} --mask=${BRAINMASK} --acqp=${OUTDIR}/acqparams.txt --index=${OUTDIR}/index.txt --bvecs=${BVEC} --bvals=${BVAL} --out=${OUTDIR}/${PREFIX} --niter=8 --fwhm=10,6,4,2,0,0,0,0 -v
fi

