#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------------------------
`basename $0` extracts slice timing of BOLD fMRI images from dcm2niix JSON file
---------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/rest.json
        -b /home/alex/output
        -c rest_st
---------------------------------------------------------------------------------
Required arguments:
        -a:  JSON file created by dcm2niix
        -b:  output directory
        -c:  output prefix

Optional arguments:
        -d:  convert second into millisecond
---------------------------------------------------------------------------------
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
          a) ## JSON file
             JSONFILE=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## convert into millisecond
             MS=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -a ${JSONFILE} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## if convert into millisecond
if [[ -z ${MS} ]]
then
    MS=0
fi

Rscript ${PhiPipe}/R/extract_slicetime.R ${JSONFILE} ${OUTDIR}/${PREFIX}.txt ${MS}

## if output file exists
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/${PREFIX}.txt
if [[ $? -eq 1 ]]
then
    exit 1
fi
