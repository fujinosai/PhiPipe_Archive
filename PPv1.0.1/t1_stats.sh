#! /bin/bash

## retrieve morphological measures from FreeSurfer recon-all results
## written by Alex / 2019-01-15 / free_learner@163.com 
## revised by Alex / 2019-06-25 / free_learner@163.com
## revised by Alex / 2019-09-12 / free_learner@163.com
## revised by Alex / 2020-03-31 / free_learner@163.com

## print function usage
function Usage {
    cat <<USAGE

`basename $0` retrieves morphological measures from FreeSurfer recon-all results

Usage example:

bash $0 -a /home/alex/data/freesurfer -b /home/alex/data/stats

Required arguments:

        -a:  FreeSurfer recon-all directory   
        -b:  output directory

USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 2 ]] ; then
  Usage >&2
  exit 1
else
  while getopts "a:b:" OPT
    do
      case $OPT in
          a) ## recon-all directory
             RECONALL=$OPTARG
             ;;
          b) ## output 
             OUTPUT=$OPTARG
             ;;
          *) ## getopts issues an error message
             echo "ERROR:  unrecognized option -$OPT $OPTARG"
             exit 1
             ;;
      esac
  done
fi

## retrieval of volume and thickness measures
export SUBJECTS_DIR=$(dirname ${RECONALL})
SUBJECT=$(basename ${RECONALL})
for hemi in lh rh
do
    for meas in thickness volume area
    do
          aparcstats2table --subjects ${SUBJECT} --hemi ${hemi} --parc aparc --meas ${meas} --tablefile ${OUTPUT}/DK_${hemi}_${meas}.txt
    done
done
asegstats2table --subjects ${SUBJECT} --meas volume --tablefile ${OUTPUT}/Aseg_volume.txt

