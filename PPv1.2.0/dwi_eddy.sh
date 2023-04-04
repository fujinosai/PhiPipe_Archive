#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
-----------------------------------------------------------------------------------
`basename $0` performs eddy, motion correction & outlier replacement of DWI images
-----------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/dwi.nii.gz 
        -b /home/alex/output
        -c eddy_correct 
        -d /home/alex/input/bvals
        -e /home/alex/input/bvecs
        -f /home/alex/input/dwi_brainmask.nii.gz
        -g 2
        -h 1
-----------------------------------------------------------------------------------
Required arguments:
        -a:  4D DWI image
        -b:  output directory
        -c:  output prefix
        -d:  b values
        -e:  b vectors
        -f:  DWI brain mask
        -g:  phase encoding direction (1/2/3:X/Y/Z)

Optional arguments:
        -h:  enable outlier replacement (default:1)
-----------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments 
if [[ $# -lt 14 ]]
then
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
          f) ## DWI brain mask
             DWIBRAINMASK=$OPTARG
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

## Enable outlier replacement by default
if [[ -z ${REPOL} ]]
then
    REPOL=1
fi

## create acqparams.txt & index.txt files
## the accurate readout time is not useful for most cases: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/Faq
## the phase encoding direction could be inferred from the direction of distortion, the sign (polarity) of which does not matter: https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind2009&L=FSL&P=R89865
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
## outlier replacement is optional but always encouraged: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/UsersGuide 
## --niter=8  and --fwhm=10,6,4,2,0,0,0,0 help when subjects had large movements: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/eddy/Faq
## the first volume defines the reference space in eddy: https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind1603&L=FSL&D=0&P=39017
## the --cnr_maps will generate contrast-to-noise ratio for each shell, which is useful for quality check
if [[ ${REPOL} -eq 1 ]]
then
    eddy_openmp --imain=${DWIIMAGE} --mask=${DWIBRAINMASK} --acqp=${OUTDIR}/acqparams.txt --index=${OUTDIR}/index.txt --bvecs=${BVEC} --bvals=${BVAL} --out=${OUTDIR}/${PREFIX} --repol --niter=8 --fwhm=10,6,4,2,0,0,0,0 --cnr_maps -v
else
    eddy_openmp --imain=${DWIIMAGE} --mask=${DWIBRAINMASK} --acqp=${OUTDIR}/acqparams.txt --index=${OUTDIR}/index.txt --bvecs=${BVEC} --bvals=${BVAL} --out=${OUTDIR}/${PREFIX} --niter=8 --fwhm=10,6,4,2,0,0,0,0 --cnr_maps -v
fi
## calculate the average Contrast-to-Noise Ratio to measure data quality after eddy
CNR=($(3dmaskave -mask ${DWIBRAINMASK} -quiet ${OUTDIR}/${PREFIX}.eddy_cnr_maps.nii.gz | tail -n +2))
echo ${CNR[*]} > ${OUTDIR}/${PREFIX}.CNR

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.nii.gz -a ${OUTDIR}/${PREFIX}.eddy_rotated_bvecs
if [[ $? -eq 1 ]]
then
    exit 1
fi
