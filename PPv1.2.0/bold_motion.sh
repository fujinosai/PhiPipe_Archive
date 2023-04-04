#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------------------------------
`basename $0` performs head motion correction and computes head motion measures
---------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/rest.nii.gz 
        -b /home/alex/output 
        -c rest 
        -d /home/alex/input/rest_ref.nii.gz
        -e 5
        -f 0.5
---------------------------------------------------------------------------------------
Required arguments:
        -a:  4D BOLD fMRI image
        -b:  output directory
        -c:  output prefix

Optional arguments:
        -d:  reference image for motion correction (default: median volume)
        -e:  number of dummy scans to be removed (default: 0)
        -f:  Power's FD (framewise-displacement) threshold to detect large head motion volumes (defalut: 0.5mm)
---------------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments 
if [[ $# -lt 6 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:" OPT
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
          d) ## reference image
             REFIMAGE=$OPTARG
             ;;
          e) ## number of dummy scans
             DVOL=$OPTARG
             ;;
          f) ## fd threshold
             THRESH=$OPTARG
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
if [[ ! -z ${REFIMAGE} ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${REFIMAGE} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## the number of dummy scans to be removed
if [[ -z ${DVOL} ]]
then
    DVOL=0
fi

## In previous versions, motion correction is performed using FSL's mcflirt. I realized that there are risks in mixing different softwares, for instance, different ways in treating the header. As the most steps in dealing with resting-state fMRI are performed using AFNI's commands, I choose to replace FSL's mcflirt with AFNI's 3dvolreg

## the FD threshold to detect motion outliers
## FD=0.5mm is sort of lenient to avoid too much loss of degrees of freedom (DoF)
## the FD is related to repetition time (TR) and FD=0.5mm I think is approriate for TR=2-3s.
## the Power's FD is about twice as large as the Jenkinson's FD, which should be noted when reading papers
## Reference: Ciric et al., 2018, Mitigating head motion artifact in functional connectivity MRI
## Reference: Power et al., 2015, Recent progress and outstanding issues in motion correction in resting state fMRI 
if [[ -z ${THRESH} ]]
then
    THRESH=0.5
fi

## whether remove first few volumes
if [[ ${DVOL} -gt 0 ]]
then
     ## _dr means dummy scans removed
     ## the volume index starts at 0, and $ means the last volume
     3dTcat -prefix ${OUTDIR}/${PREFIX}_dr.nii.gz "${BOLDIMAGE}[${DVOL}..$]"
else
     ln -s ${BOLDIMAGE} ${OUTDIR}/${PREFIX}_dr.nii.gz
fi

## extract mid-time volume as reference file or use explicit reference file for registration
if [[ ! -z ${REFIMAGE} ]]
then
     cp ${REFIMAGE} ${OUTDIR}/${PREFIX}_ref.nii.gz
else
     TOTVOL=$(3dinfo -nt ${OUTDIR}/${PREFIX}_dr.nii.gz)
     MIDVOL=$(( ${TOTVOL} / 2 ))
     3dTcat -prefix ${OUTDIR}/${PREFIX}_ref.nii.gz "${OUTDIR}/${PREFIX}_dr.nii.gz[$MIDVOL]"
fi    

## motion correction
3dvolreg -base ${OUTDIR}/${PREFIX}_ref.nii.gz -prefix ${OUTDIR}/${PREFIX}_mc.nii.gz -1Dfile ${OUTDIR}/${PREFIX}_mc.matrix -twopass -heptic ${OUTDIR}/${PREFIX}_dr.nii.gz

## compute Power's framewise displacement, motion parameter expansions and motion outliers
Rscript ${PhiPipe}/R/motion_metrics.R ${OUTDIR}/${PREFIX} ${THRESH}

## plot motion parameters
1dplot -one -ylabel 'Estimated Rotations (degree)' -ynames Rx Ry Rz -png ${OUTDIR}/mytmp_rot.png "${OUTDIR}/${PREFIX}_mc.matrix[1,2,0]"
1dplot -one -ylabel 'Estimated Translations (mm)' -ynames Tx Ty Tz -png ${OUTDIR}/mytmp_trans.png "${OUTDIR}/${PREFIX}_mc.matrix[4,5,3]"
1dplot -one -ylabel 'Framewise Displacement (mm)' -ynames FD -png ${OUTDIR}/mytmp_fd.png ${OUTDIR}/${PREFIX}_mc.fd
## append figures
convert ${OUTDIR}/mytmp_rot.png ${OUTDIR}/mytmp_trans.png ${OUTDIR}/mytmp_fd.png +append ${OUTDIR}/${PREFIX}_motion.png

## remove temporary files
rm ${OUTDIR}/mytmp* 
rm ${OUTDIR}/${PREFIX}_dr.nii.gz

## check the existence of output files
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}_mc.nii.gz -a ${OUTDIR}/${PREFIX}_mc.matrix -a ${OUTDIR}/${PREFIX}_mc.metric
if [[ $? -eq 1 ]]
then
    exit 1
fi

