#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
--------------------------------------------------------------------------------------------------
`basename $0` performs outlier interpolation, nuisance regression and temporal filtering together
--------------------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bold.nii.gz 
        -b /home/alex/output
        -c bold_res 
        -d /home/alex/input/bold_mc.model
        -d /home/alex/input/bold_wmmean.txt 
        -d /home/alex/input/bold_csfmean.txt 
        -e /home/alex/input/bold_mc.censor
        -f 0.01 
        -g 0.1 
        -h 2 
        -i /home/alex/input/bold_brainmask.nii.gz
--------------------------------------------------------------------------------------------------
Required arguments:
        -a: 4D BOLD fMRI images  
        -b: output directory
        -c: output prefix
        -d: nuisance signals

Optional arguments:
        -e: outliers to be censored
        -f: high pass frequency
        -g: low pass frequency
        -h: repetition time
        -i: BOLD image mask
--------------------------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 8 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:g:h:i:" OPT
    do
      case $OPT in
          a) ## 4D BOLD fMRI image
             BOLDIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## nuisance signals
             NUISANCE+=("$OPTARG")
             ;;
          e) ## outlier 1D file
             OUTLIER=$OPTARG
             ;;
          f) ## high pass frequency
             FBOT=$OPTARG
             ;;
          g) ## low pass frequency
             FTOP=$OPTARG
             ;;
          h) ## repetition time
             TR=$OPTARG
             ;;
          i) ## BOLD image mask
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
## deal with multiple types of nuisance signals
for i in "${NUISANCE[@]}"
do
    CMD="${CMD} -a ${i}"
done
if [[ ! -z ${OUTLIER} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${OUTLIER} ${CMD} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} ${CMD} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## whether temporal filtering
if [[ -z ${TR} ]]
then
   TR=$(fslval ${BOLDMAGE} pixdim4)
fi
if [[ -z ${FBOT} ]]
then
    FBOT=0
fi
if [[ -z ${FTOP} ]]
then
    FTOP=99999
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

## nuisance regression
## if FBOT =0 & FTOP=99999, no filtering was performed except for removal of the 0 and Nyquist frequencies
## in previous version, the outlier interpolation was performed seperately from the nuisance regression & filtering to make the script always run "smoothly" (because too much loss of DOF will result in errors). But in fact, these data (lack of DOF) should not be analysed further. So in this version, outlier interpolation and nuisance regression/filtering were done simutaneously.
## low-pass filtering will reduce a lot of DOF, and neural signals do exist in higher frequencies. But low-pass filtering was still a common practice. More evidence is needed in the choice of low-pass filtering. 
## If the scan duration is short or the TR is short, low-pass filtering should not be performed. https://afni.nimh.nih.gov/pub/dist/doc/htmldoc/programs/afni_proc.py_sphx.html#resting-state-note  
## By default, 3dTproject also remove linear & quadratic trends, which is also suggested: https://afni.nimh.nih.gov/afni/community/board/read.php?1,165243,165256#msg-165256
## deal with multiple types of nuisance signals
CMD02=$(echo "${CMD[@]}"  | sed s/-a/-ort/g)
3dTstat -mean -prefix ${OUTDIR}/mytmp_mean.nii.gz ${BOLDIMAGE}
if [[ -z ${OUTLIER} ]]
then
    3dTproject -input ${BOLDIMAGE} -prefix ${OUTDIR}/mytmp_res.nii.gz -mask ${MASK} ${CMD02} -passband ${FBOT} ${FTOP} -dt ${TR}
else
    3dTproject -input ${BOLDIMAGE} -prefix ${OUTDIR}/mytmp_res.nii.gz -mask ${MASK} -censor ${OUTLIER} -cenmode NTRP ${CMD02} -passband ${FBOT} ${FTOP} -dt ${TR}
fi
3dcalc -a ${OUTDIR}/mytmp_res.nii.gz -b ${OUTDIR}/mytmp_mean.nii.gz -c ${MASK} -expr '(a+b)*c' -prefix ${OUTDIR}/${PREFIX}.nii.gz

## remove temporary files
rm ${OUTDIR}/mytmp*

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
