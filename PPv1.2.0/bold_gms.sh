#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------
`basename $0` performs grand mean scaling to 10000
---------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold.nii.gz
        -b /home/alex/output
        -c bold_gms
        -d /home/alex/input/bold_brainmask.nii.gz
---------------------------------------------------
Required arguments:
        -a:  4D BOLD image
        -b:  output directory
        -c:  output prefix

Optional arguments:         
        -d:  BOLD brain mask
---------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 6 ]]
then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:" OPT
    do
      case $OPT in
          a) ## bold image
             BOLDIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## mask
             MASK=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## whether a mask provided
if [[ -z ${MASK} ]]
then
    3dAutomask -prefix ${OUTDIR}/mytmp_mask.nii.gz ${BOLDIMAGE}
    MASK=${OUTDIR}/mytmp_mask.nii.gz
else
    if [[ ! -f ${MASK} ]]
    then
        echo "File ${MASK} doesn't exist. Please check !!!"
        exit
    fi    
fi

## grand mean scaling to 10000
3dTstat -mean -mask ${MASK} -prefix ${OUTDIR}/mytmp_mean.nii.gz ${BOLDIMAGE}
GRANDMEAN=$(3dmaskave -mask ${MASK} -quiet ${OUTDIR}/mytmp_mean.nii.gz)
3dcalc -a ${BOLDIMAGE} -b ${MASK} -expr "a*10000/${GRANDMEAN}*b" -prefix ${OUTDIR}/${PREFIX}.nii.gz

## remove temporary files
rm ${OUTDIR}/mytmp*

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
