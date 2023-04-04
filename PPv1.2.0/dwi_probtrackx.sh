#! /bin/bash

## Author: Yang Hu / free_learner@163.com / learning-archive.org

## print script usage
Usage () {
    cat <<USAGE
---------------------------------------------------------------------------------------------------
`basename $0` constructs structural connectivity probability matrix via probabilistic tractography 
---------------------------------------------------------------------------------------------------
Usage example:

bash $0 -a /home/alex/input/bedpostx
        -b /home/alex/output
        -c DKAseg_prob
        -d /home/alex/input/dwi_DKAseg.nii.gz
        -e /home/alex/input/DKAseg_labels.txt
---------------------------------------------------------------------------------------------------
Required arguments:
        -a: bedpostx directory
        -b: output directory
        -c: output prefix
        -d: ROI masks
        -e: ROI labels
---------------------------------------------------------------------------------------------------
USAGE
    exit 1
}

## parse arguments
if [[ $# -lt 10 ]] ; then
    Usage >&2
    exit 1
else
    while getopts "a:b:c:d:e:" OPT
    do
      case $OPT in
          a) ## bedpostx directory
             BEDPOSTX=$OPTARG
             ;;
          b) ## output directory
             OUTDIR=$OPTARG
             ;;
          c) ## output prefix
             PREFIX=$OPTARG
             ;;
          d) ## ROI mask
             ROIMASK=$OPTARG
             ;;
          e) ## ROI label
             LABEL=$OPTARG
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
bash ${PhiPipe}/check_inout.sh -a ${ROIMASK} -b ${BEDPOSTX} -b ${OUTDIR}
if [[ $? -eq 1 ]]
then
    exit 1
fi

## split ROI masks
mkdir -p ${OUTDIR}/mytmp_roimask
for idx in $(cat ${LABEL} | awk '{print $1}')
do
    3dcalc -a ${ROIMASK} -expr "not(a-${idx})" -prefix ${OUTDIR}/mytmp_roimask/roi${idx}.nii.gz
    ls ${OUTDIR}/mytmp_roimask/roi${idx}.nii.gz >> ${OUTDIR}/mytmp_roimask/masks.txt
done

## probablistic tractography
## In previous version, --omatrix1 & --ompl  was added. However, the output files take a lot of memory (about 8G at normal resolution). I had no idea about the application of these outputs. So in this version, I omitted these options to save space.
## https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind1909&L=FSL&D=0&K=2&P=181801
probtrackx2 --network -x ${OUTDIR}/mytmp_roimask/masks.txt -l --onewaycondition --opd -c 0.2 -S 2000 --steplength=0.5 -P 5000 --fibthresh=0.01 --distthresh=0.0 --sampvox=0.0 --forcedir -s ${BEDPOSTX}/merged -m ${BEDPOSTX}/nodif_brain_mask --dir=${OUTDIR}

## check ROI coverage
bash ${PhiPipe}/roi_stats.sh -a ${BEDPOSTX}/nodif_brain_mask.nii.gz -b ${OUTDIR} -c ${PREFIX} -d ${ROIMASK} -e ${LABEL}
rm ${OUTDIR}/${PREFIX}.mean

## compute structural connectivity probability matrix by normalizing the streamline count matrix with ROI size
## https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind2001&L=FSL&D=0&P=143270
## https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind2008&L=FSL&D=0&P=239180
Rscript ${PhiPipe}/R/conn_prob.R ${OUTDIR}/fdt_network_matrix ${OUTDIR}/${PREFIX}.info ${OUTDIR}/${PREFIX}.matrix

## remove temporary files
rm -r ${OUTDIR}/mytmp_roimask

## check whether the output files exist
bash ${PhiPipe}/check_inout.sh -a ${OUTDIR}/fdt_network_matrix -a ${OUTDIR}/${PREFIX}.matrix -a ${OUTDIR}/fdt_paths.nii.gz
if [[ $? -eq 1 ]]
then
    exit 1
fi
