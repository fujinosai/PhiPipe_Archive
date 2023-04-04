#! /bin/bash

## nuisance regression and temporal filtering using AFNI 3dTproject
## written by Alex / 2019-01-09 / free_learner@163.com
## revised by Alex / 2019-03-05 / free_learner@163.com
## revised by Alex / 2019-06-26 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` performs nuisance regression and temporal filtering together

Usage example:

bash $0 -a /home/alex/data/bold.nii.gz 
        -b /home/alex/data
        -c bold_res 
        -d /home/alex/data/bold_mc.model
        -d /home/alex/data/bold_wmmean.txt 
        -d /home/alex/data/bold_csfmean.txt 
        -e /home/alex/data/bold_mc.censor
        -f 0.01 
        -g 0.1 
        -h 2 
        -i /home/alex/data/bold_brainmask.nii.gz

Required arguments:

        -a: 4D bold fMRI images  
        -b: output directory
        -c: output prefix
        -d: nuisance signals

Optional arguments:

        -e: outliers to be censored
        -f: high pass frequency
        -g: low pass frequency
        -h: repetition time
        -i: bold image mask

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 4 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:c:d:e:f:g:h:i:" OPT
    do
      case $OPT in
          a) ## 4D bold fMRI image
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
          i) ## bold image mask
             MASK=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## deal with multiple types of nuisance signals
for i in "${NUISANCE[@]}"
do
    CMD="${CMD} -ort ${i}"
done

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
fi

## nuisance regression
3dTstat -mean -prefix ${OUTDIR}/mytmp_mean.nii.gz ${BOLDIMAGE}
if [[ -z ${OUTLIER} ]]
then
    3dTproject -input ${BOLDIMAGE} -prefix ${OUTDIR}/mytmp_res.nii.gz -mask ${MASK} ${CMD} -passband ${FBOT} ${FTOP} -dt ${TR}
else
    3dTproject -input ${BOLDIMAGE} -prefix ${OUTDIR}/mytmp_censored.nii.gz -censor ${OUTLIER} -cenmode NTRP -polort 0 
    3dTproject -input ${OUTDIR}/mytmp_censored.nii.gz -prefix ${OUTDIR}/mytmp_res.nii.gz -mask ${MASK} ${CMD} -passband ${FBOT} ${FTOP} -dt ${TR}
fi
3dcalc -a ${OUTDIR}/mytmp_res.nii.gz -b ${OUTDIR}/mytmp_mean.nii.gz -c ${MASK} -expr '(a+b)*c' -prefix ${OUTDIR}/${PREFIX}.nii.gz

## remove temporary files
rm ${OUTDIR}/mytmp*

