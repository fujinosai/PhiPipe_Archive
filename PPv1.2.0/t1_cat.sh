#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
----------------------------------------------------------------------------------
`basename $0` performs CAT12 pipeline for skull stripping
----------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/t1.nii.gz
        -b /home/alex/output
        -c t1
        -d /home/alex/input/cat12_defaults.m
----------------------------------------------------------------------------------
Required arguments:
        -a: T1-weighted raw image 
        -b: output directory
        -c: output prefix

Optional arguments:
        -d: CAT12 parameter file
        -e: skull stripping algorithm (0: SPM, 1: gcut, 2: new APRG, default: 2)
        -f: cleanup strength (0-1, default: 0.1)
----------------------------------------------------------------------------------
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
          a) ## T1 input file
             T1IMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## default parameter file
             CAT_DEFAULT=$OPTARG
             ;;
          e) ## skull stripping algorithm
             ALGO=$OPTARG
             ;;
          f) ## cleanup strength
             CLEANUP=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
    done
fi

## Based on my personal experience, I found that CAT12's skull stripping is more accurate and robust than FreeSurfer's, so that I tried to replace FreeSurfer's skull removal with CAT12's. This observation is still unvalidated. Besides, CAT12 depends on MATLAB environment. This dependence will influence the pipeline's usability. When I found good alternatives, CAT12 would be removed.

## if PhiPipe variable is set?
## this script will call other scripts so that PhiPipe variable must be set. 
if [[ -z ${PhiPipe} ]]
then
    echo "Please set the \$PhiPipe environment variable !!!"
    exit 1
fi

## if default parameter file given?
if [[ -z ${CAT_DEFAULT} ]]
then
    CAT_DEFAULT=${PhiPipe}/matlab/cat_defaults.m
fi

## if INPUT file/OUTPUT folder exist?
## if the OUTPUT folder doesn't exist, exit instead of creating the folder,
## because creating the nonexistent folder may mess up the filesystem.
bash ${PhiPipe}/check_inout.sh -a ${T1IMAGE} -a ${CAT_DEFAULT} -b ${OUTDIR}
## if INPUT file/OUTPUT folder doesn't exist (exit status equals 1), quit the script
if [[ $? -eq 1 ]]
then
    exit 1
fi

## if set algorithm?
if [[ -z ${ALGO} ]]
then
    ALGO=2
fi

## if set cleanup strength?
## the CLEANUP parameter only had small effects on the final skull removal, 0.1 would lead to a more loose mask
## there seems always a tradeoff between skull removal and gray matter removal, I always choose to avoid gray matter removal
## and hope downstream algorithms will corret small errors.
if [[ -z ${CLEANUP} ]]
then
    CLEANUP=0.1
fi

## check if INPUT file in zipped format
if [[ ${T1IMAGE} = *.gz ]]
then
    ## CAT12 can't deal with zipped format
    gunzip -c ${T1IMAGE} > ${OUTDIR}/${PREFIX}.nii
else
    ## CAT12 generates output in the same folder as the INPUT file
    ## so copy the INPUT file to the OUTPUT folder
    cp ${T1IMAGE} ${OUTDIR}/${PREFIX}.nii
fi

## invoke cat_batch_cat.m to run CAT12 pipeline
echo ${OUTDIR}/${PREFIX}.nii > ${OUTDIR}/input_file.txt
COMMAND="global ALGO CLEANUP;ALGO=$ALGO;CLEANUP=$CLEANUP;cat_batch_cat('${OUTDIR}/input_file.txt','${CAT_DEFAULT}')"
matlab -nodisplay -nosplash -nodesktop -r "$COMMAND"
## zip file to save space
gzip ${OUTDIR}/p0${PREFIX}.nii

## CAT12 outputs a measure of image quality: http://www.neuro.uni-jena.de/cat12-html/cat_methods_QA.html
QCSCORE=$(cat ${OUTDIR}/catlog_${PREFIX}.txt | grep "Image Quality Rating" | awk {'print $5'} | sed s/%//)
QCLEVEL=$(cat ${OUTDIR}/catlog_${PREFIX}.txt | grep "Image Quality Rating" | awk {'print $6'} | sed  s/\(// | sed s/\)//)
printf "%s\t%s\n" ${QCSCORE} ${QCLEVEL} > ${OUTDIR}/${PREFIX}_IQR.txt

## extract the estimated total intracranial volume (TIV, also called ICV)
TIV=$(cat ${OUTDIR}/cat_${PREFIX}.xml | grep vol_TIV | sed -n 1p | cut -d '>' -f2 | cut -d '<' -f1)
echo $TIV > ${OUTDIR}/${PREFIX}_TIV.txt

## the partial volume image was thresholded at 0.5 to create the brain mask
## 0-1 means the voxel contains both background and CSF
## 0.5 means the voxel contains more CSF than background was treated as part of the brain
## external CSF was included to get a loose brain mask
## reference: https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind1906&L=SPM&P=R62408
mri_binarize --i ${OUTDIR}/p0${PREFIX}.nii.gz --min 0.5 --o ${OUTDIR}/${PREFIX}_brainmask.nii.gz

## quality check of the skull stripping
bash ${PhiPipe}/plot_overlay.sh -a ${T1IMAGE} -b ${OUTDIR}/${PREFIX}_brainmask.nii.gz -c ${OUTDIR} -d ${PREFIX}_brainmask -e 2 -f 1

## remove temporary file
rm ${OUTDIR}/${PREFIX}.nii

## check whether the output files exist to ensure the success of this step
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/p0${PREFIX}.nii.gz -a ${OUTDIR}/${PREFIX}_brainmask.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
