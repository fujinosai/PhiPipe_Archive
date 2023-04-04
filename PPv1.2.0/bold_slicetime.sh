#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage() {
    cat <<USAGE
-----------------------------------------------------------------------------
`basename $0` performs slice timing correction of BOLD fMRI images
-----------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/rest.nii.gz 
        -b /home/alex/output
        -c rest_st
        -d 2 
        -e 4
-----------------------------------------------------------------------------
Required arguments:
        -a:  4D BOLD fMRI image
        -b:  output directory
        -c:  output prefix
        -d:  repetition time (in seconds)
        -e:  slice timing type
        -f:  slice timing file (used when slice timing type is set to 7)

Slice timing type:
        0: no slice timing correction (potentially for multi-band acquisition)
        1: seqplus (1 2 3 ...)
        2: seqminus (... 3 2 1)
        3: altplus (1 3 5 ... 2 4 6 ...)
        4: altplus2 (2 4 6 ... 1 3 5 ...)
        5: altminus (n n-2 n-4 ... n-1 n-3 n-5 ...)
        6: altminus2 (n-1 n-3 n-5 ... n n-2 n-4)
        7: custom slice timing file (potentially for multi-band acquisition)
------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 10 ]]
then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:f:" OPT
    do
      case $OPT in
          a) ## BOLD fMRI file
             BOLDIMAGE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## repetition time
             TR=$OPTARG
             ;;
          e) ## slice time type
             STTYPE=$OPTARG
             ;;
          f) ## slice time file
             STFILE=$OPTARG
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
if [[ ${STTYPE} -eq 7 ]]
then
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -a ${STFILE} -b ${OUTDIR}
else
    bash ${PhiPipe}/check_inout.sh -a ${BOLDIMAGE} -b ${OUTDIR}
fi
if [[ $? -eq 1 ]]
then
    exit 1
fi

## slice timing correction using AFNI's 3dTshift
## the unit of TR could be second or millisecond, the results would be the same after a test
## if the slice timing file was provided, the unit of TR should be matched to the file 
## the interpolation method was set to -heptic, https://afni.nimh.nih.gov/afni/community/board/read.php?1,166247,166248#msg-166248
## After simple test, the difference between the default interpolation (-Fourier) and -heptic, the difference lies in the edges of the brain
## I also applied 3dTshift twice (see 3dTshift's help) with inverse tpattens sequentially (for instance, alt+z & alt-z), the difference also lies in the edges of the brain.
## A potential alternative is FSL's slicetimer. However, I found strange results using slicetimer: https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind1806&L=FSL&P=R47292  
## Chris Rorden's introduction for slice timing: https://crnl.readthedocs.io/stc/index.html
case ${STTYPE} in
     0) cp ${BOLDIMAGE} ${OUTDIR}/${PREFIX}.nii.gz;;
     1) 3dTshift -verbose -TR ${TR} -tpattern seq+z  -heptic -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     2) 3dTshift -verbose -TR ${TR} -tpattern seq-z  -heptic -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     3) 3dTshift -verbose -TR ${TR} -tpattern alt+z  -heptic -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     4) 3dTshift -verbose -TR ${TR} -tpattern alt+z2 -heptic -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     5) 3dTshift -verbose -TR ${TR} -tpattern alt-z  -heptic -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     6) 3dTshift -verbose -TR ${TR} -tpattern alt-z2 -heptic -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     7) 3dTshift -verbose -TR ${TR} -tpattern @${STFILE} -heptic -prefix ${OUTDIR}/${PREFIX}.nii.gz ${BOLDIMAGE};;
     *) echo "incorrect slice timing option";;
esac

## check the existence of output files
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi

