#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------------
`basename $0` estimates fiber orientation distribution for DWI images
-----------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/dwi.nii.gz
        -b /home/alex/output
        -c bedpostx
        -d /home/alex/input/dwi_brainmask.nii.gz
        -e /home/alex/input/bvals
        -f /home/alex/input/bvecs
-----------------------------------------------------------------------
Required arguments:
        -a: 4D DWI images  
        -b: output directory
        -c: output subfolder
        -d: DWI brain mask
        -e: b values
        -f: b vectors

Optional arguments:
        -g: number of fibres (default: 3)
        -h: model (default: 2)        
-----------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 12 ]]
then
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
          c) ## output subfolder
             SUBDIR=$OPTARG
             ;;
          d) ## brain mask
             DWIBRAINMASK=$OPTARG
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

## renaming files for bedpostx
mkdir -p ${OUTDIR}/mytmpdir
ln -s ${DWIIMAGE} ${OUTDIR}/mytmpdir/data.nii.gz
ln -s ${DWIBRAINMASK} ${OUTDIR}/mytmpdir/nodif_brain_mask.nii.gz
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
## selection of fibre numbers: https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind2010&L=FSL&P=R155869
if [[ -z ${NFIBRES} ]]
then
  NFIBRES=3
fi
## if single-shell data, model=1 should be used: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FDT/UserGuide
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
mv ${OUTDIR}/mytmpdir.bedpostX ${OUTDIR}/${SUBDIR}

## remove temporary files
rm -r ${OUTDIR}/mytmpdir

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${SUBDIR}/merged_f1samples.nii.gz -a ${OUTDIR}/${SUBDIR}/merged_ph1samples.nii.gz -a ${OUTDIR}/${SUBDIR}/merged_th1samples.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi

