#! /bin/bash

## estimate fiber orientation distribution for dwi images using FSL' bedpostx
## written by Alex / 2019-09-04 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` estimates fiber orientation distribution for dwi images using FSL' bedpostx

Usage example:

bash $0 -a /home/alex/data/dwi.nii.gz
        -b /home/alex/data
        -c bedpostx
        -d /home/alex/data/dwi_brainmask.nii.gz
        -e /home/alex/data/bvals
        -f /home/alex/data/bvecs

Required arguments:

        -a: 4D dwi images  
        -b: output directory
        -c: output prefix
        -d: dwi brain mask
        -e: b values
        -f: b vectors

Optional arguments:

        -g: number of fibres
        -h: model       

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:" OPT
    do
      case $OPT in
          a) ## dwi image file
             DWIIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## brain mask
             BRAINMASK=$OPTARG
             ;;
          e) ## b values
             BVAL=$OPTARG
             ;;
          f) ## b vectors
             BVEC=$OPTARG
             ;;
          g) ## fibre numbers
             NFIBRES=$OPTARG
             ;;
          h) ## model
             MODEL=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## renaming files for bedpostx
mkdir -p ${OUTDIR}/mytmpdir
ln -s ${DWIIMAGE} ${OUTDIR}/mytmpdir/data.nii.gz
ln -s ${BRAINMASK} ${OUTDIR}/mytmpdir/nodif_brain_mask.nii.gz
ln -s ${BVAL} ${OUTDIR}/mytmpdir/bvals
ln -s ${BVEC} ${OUTDIR}/mytmpdir/bvecs

## bedpostx-preproc
GFLAG=0
mkdir -p ${OUTDIR}/mytmpdir.bedpostX
mkdir -p ${OUTDIR}/mytmpdir.bedpostX/diff_slices
mkdir -p ${OUTDIR}/mytmpdir.bedpostX/logs
mkdir -p ${OUTDIR}/mytmpdir.bedpostX/logs/monitor
mkdir -p ${OUTDIR}/mytmpdir.bedpostX/xfms
bedpostx_preproc.sh ${OUTDIR}/mytmpdir ${GFLAG}

## bedpostx
if [[ -z ${NFIBRES} ]]
then
  NFIBRES=3
fi
if [[ -z ${MODEL} ]]
then
  MODEL=2
fi
FUDGE=1
BURNIN=1000
NJUMPS=1250
SAMPLEEVERY=25
nslices=$(fslval ${OUTDIR}/mytmpdir/data dim3)
slice=0
while [ $slice -lt $nslices ]
do
   bedpostx_single_slice.sh ${OUTDIR}/mytmpdir ${slice} --nf=$NFIBRES --fudge=$FUDGE --bi=$BURNIN --nj=$NJUMPS --se=$SAMPLEEVERY --model=$MODEL --cnonlinear
   slice=$(($slice + 1))
done

## bedpostx-postproc
bedpostx_postproc.sh ${OUTDIR}/mytmpdir

## renaming
mv ${OUTDIR}/mytmpdir.bedpostX ${OUTDIR}/${PREFIX}

## remove temporary files
rm -r ${OUTDIR}/mytmpdir
